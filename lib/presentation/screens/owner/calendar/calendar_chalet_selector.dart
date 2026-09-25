part of 'owner_calendar_screen.dart';

extension _CalendarChaletSelector on _OwnerCalendarScreenState {
  Widget _chaletSelector() {
    if (_chalets.length <= 1) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Row(
          children: [
            const Icon(Icons.home_work_rounded,
                size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_chalet!.name,
                  key: const Key('chalet_title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.charcoal)),
            ),
          ],
        ),
      );
    }
    return SizedBox(
      height: 50,
      child: ListView.separated(
        key: const Key('chalet_chips'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        itemCount: _chalets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final c = _chalets[i];
          final selected = c.id == _chalet?.id;
          final pending = _pending[c.id] ?? 0;
          return ChoiceChip(
            key: Key('chalet_chip_${c.id}'),
            selected: selected,
            selectedColor: AppColors.primary,
            backgroundColor: Colors.white,
            showCheckmark: false,
            onSelected: (_) => _selectChalet(c),
            label: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 170),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: selected ? Colors.white : AppColors.charcoal,
                        )),
                  ),
                  if (pending > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      key: Key('chalet_chip_badge_${c.id}'),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$pending',
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
