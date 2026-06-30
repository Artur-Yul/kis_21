class_name Card
extends Resource

# Перечисления для удобства чтения кода
enum Suit { SPADES, CLUBS, DIAMONDS, HEARTS } # Пики, Крести, Бубны, Черви

@export var suit: Suit
@export var rank: String # "6", "7", ..., "Jack", "Queen", "King", "Ace"
@export var value: int   # Сколько очков дает карта (например: Валет = 2, Дама = 3, Король = 4, Туз = 11)
@export var texture: Texture2D # Сюда художники потом добавят пиксель-арт карты
