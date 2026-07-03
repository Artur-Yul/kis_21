class_name GameCard
extends Resource # Или оставьте как внутренний класс, если использовали прошлый вариант

enum Suit { SPADES, CLUBS, DIAMONDS, HEARTS }

var suit: Suit
var rank: String
var value: int
var texture: Texture2D
var face_up: bool = false # По умолчанию карта лежит рубашкой вверх
