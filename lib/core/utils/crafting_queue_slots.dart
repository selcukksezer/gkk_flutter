import '../../models/player_model.dart';

const int craftingQueueMaxSlots = 5;
const int craftingQueueBaseSlots = 1;

const Map<int, int> craftingQueueSlotUnlockCosts = <int, int>{
  2: 20,
  3: 40,
  4: 80,
  5: 160,
};

int playerCraftingQueueSlots(PlayerProfile? profile) {
  final int slots = profile?.craftingQueueSlots ?? craftingQueueBaseSlots;
  return slots.clamp(craftingQueueBaseSlots, craftingQueueMaxSlots);
}

int? nextCraftQueueSlotUnlockCost(int currentSlots) {
  if (currentSlots >= craftingQueueMaxSlots) return null;
  return craftingQueueSlotUnlockCosts[currentSlots + 1];
}

bool canExpandCraftQueue(int currentSlots) =>
    currentSlots < craftingQueueMaxSlots;
