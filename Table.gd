extends Node

# Массив, где будет храниться текущая колода
var deck: Array[Card] = []

# Масти и ранги для генерации стандартной колоды из 36 карт
const SUITS = [Card.Suit.SPADES, Card.Suit.CLUBS, Card.Suit.DIAMONDS, Card.Suit.HEARTS]
const RANKS = {
	"6": 6, "7": 7, "8": 8, "9": 9, "10": 10,
	"Jack": 2,   # Валет
	"Queen": 3,  # Дама
	"King": 4,   # Король
	"Ace": 11    # Туз (в классических правилах 21 очка обычно равен 11)
}

func _ready() -> void:
	randomize() # Инициализируем генератор случайных чисел
	generate_deck()
	shuffle_deck()
	
	# ТЕСТОВЫЙ ЗАПУСК: Раздадим карты игроку
	var test_hand: Array[Card] = []
	test_hand.append(draw_card())
	test_hand.append(draw_card())
	
	print("Карты в руке:")
	for card in test_hand:
		print("- %s %s (Очков: %d)" % [card.rank, Card.Suit.keys()[card.suit], card.value])
		
	print("Всего очков: ", calculate_score(test_hand))

# Функция генерации новой колоды из 36 карт
func generate_deck() -> void:
	deck.clear()
	for suit in SUITS:
		for rank in RANKS.keys():
			var new_card = Card.new()
			new_card.suit = suit
			new_card.rank = rank
			new_card.value = RANKS[rank]
			# Здесь в будущем можно динамически подгружать текстуры, например:
			# new_card.texture = load("res://art/cards/" + rank + "_" + str(suit) + ".png")
			deck.append(new_card)
	print("Колода создана. Карт: ", deck.size())

# Функция перемешивания
func shuffle_deck() -> void:
	deck.shuffle()
	print("Колода перемешана.")

# Функция взятия карты из колоды (выдает верхнюю карту и удаляет её из массива)
func draw_card() -> Card:
	if deck.size() > 0:
		return deck.pop_back()
	else:
		print("Колода закончилась! Генерируем новую...")
		generate_deck()
		shuffle_deck()
		return deck.pop_back()

# Оптимизированная функция подсчета очков с учетом правила "Два Туза"
# (В русском 21 очко два туза в руке — это автоматическая победа / 21 очко)
func calculate_score(hand: Array[Card]) -> int:
	# Проверка на особое правило: Два Туза
	if hand.size() == 2 and hand[0].rank == "Ace" and hand[1].rank == "Ace":
		return 21
		
	var total = 0
	for card in hand:
		total += card.value
		
	return total
