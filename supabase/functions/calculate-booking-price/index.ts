import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type RequestBody = {
  chaletId?: string;
  checkIn?: string; // ISO string
  checkOut?: string; // ISO string
  guestsCount?: number;
};

type ConflictBookingRow = {
  check_in: string | null;
  check_out: string | null;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function toDateOnlyString(d: Date): string {
  // YYYY-MM-DD using UTC fields (avoids timezone off-by-one)
  const yyyy = d.getUTCFullYear();
  const mm = String(d.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(d.getUTCDate()).padStart(2, "0");
  return `${yyyy}-${mm}-${dd}`;
}

function parseDateOnlyToUTCDate(d: Date): Date {
  // Convert to date-only in UTC so comparisons are stable.
  // new Date('YYYY-MM-DD') is treated as UTC by JS (consistent for comparisons).
  return new Date(toDateOnlyString(d));
}

function diffDays(checkIn: Date, checkOut: Date): number {
  const ms = checkOut.getTime() - checkIn.getTime();
  return Math.floor(ms / (1000 * 60 * 60 * 24));
}

serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !serviceRoleKey) {
      return new Response(JSON.stringify({ error: "Server misconfiguration" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);

    const authHeader = req.headers.get("Authorization");
    const clientToken = authHeader?.startsWith("Bearer ")
      ? authHeader.slice("Bearer ".length)
      : null;

    if (!clientToken) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = (await req.json().catch(() => ({}))) as RequestBody;
    const chaletId = body?.chaletId;
    const checkIn = body?.checkIn;
    const checkOut = body?.checkOut;
    const guestsCount = body?.guestsCount;

    if (!chaletId || !checkIn || !checkOut || typeof guestsCount !== "number") {
      return new Response(JSON.stringify({ error: "Invalid payload" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const checkInDate = new Date(checkIn);
    const checkOutDate = new Date(checkOut);

    if (Number.isNaN(checkInDate.getTime()) || Number.isNaN(checkOutDate.getTime())) {
      return new Response(JSON.stringify({ error: "Invalid dates" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (checkOutDate <= checkInDate) {
      return new Response(JSON.stringify({ error: "Invalid date range" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const nights = diffDays(checkInDate, checkOutDate);
    if (nights < 1) {
      return new Response(JSON.stringify({ error: "Invalid date range" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Fetch chalet price_per_night
    const { data: chaletRow, error: chaletErr } = await supabase
      .from("chalets")
      .select("id, price_per_night, max_guests")
      .eq("id", chaletId)
      .maybeSingle();

    if (chaletErr || !chaletRow) {
      return new Response(JSON.stringify({ error: "Chalet not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (guestsCount < 1 || guestsCount > (chaletRow.max_guests ?? 9999)) {
      return new Response(JSON.stringify({ error: "Invalid guests count" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Availability check: overlapping bookings
    // Overlap rule for [in, out) semantics:
    // requested_check_in < existing_check_out AND requested_check_out > existing_check_in
    // Only consider pending/confirmed; ignore cancelled/rejected.
    const { data: conflicts, error: conflictErr } = await supabase
      .from("bookings")
      .select("check_in, check_out")
      .eq("chalet_id", chaletId)
      .in("status", ["pending", "confirmed"]);

    if (conflictErr) {
      return new Response(
        JSON.stringify({ error: "Could not validate availability" }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const requestedInUTC = parseDateOnlyToUTCDate(checkInDate);
    const requestedOutUTC = parseDateOnlyToUTCDate(checkOutDate);

    const isConflict = (conflicts ?? []).some((b: ConflictBookingRow) => {
      if (!b?.check_in || !b?.check_out) return false;

      const existingIn = new Date(b.check_in);
      const existingOut = new Date(b.check_out);
      if (Number.isNaN(existingIn.getTime()) || Number.isNaN(existingOut.getTime())) return false;

      const existingInUTC = parseDateOnlyToUTCDate(existingIn);
      const existingOutUTC = parseDateOnlyToUTCDate(existingOut);

      // Use date-only semantics for [check_in, check_out) overlap.
      // Overlap condition:
      // requested_check_in < existing_check_out AND requested_check_out > existing_check_in
      return (
        requestedInUTC.getTime() < existingOutUTC.getTime() &&
        requestedOutUTC.getTime() > existingInUTC.getTime()
      );
    });


    if (isConflict) {
      return new Response(JSON.stringify({ error: "Not available" }), {
        status: 409,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const pricePerNight = Number(chaletRow.price_per_night);
    const totalPrice = pricePerNight * nights;

    return new Response(
      JSON.stringify({
        chaletId,
        nights,
        totalPrice: Math.round(totalPrice * 100) / 100,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (_e) {
    return new Response(JSON.stringify({ error: "Internal server error" }), {
      status: 500,
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  }
});

