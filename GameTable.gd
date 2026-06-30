extends Control

# --- СТРУКТУРА КАРТЫ (Внутренний класс) ---
# Описываем, что такое карта, прямо внутри этого же скрипта для простоты
enum Suit { SPADES, CLUBS, DIAMONDS, HEARTS }

class GameCard:
	var suit: Suit
	var rank: String
	var value: int
	var texture: Texture2D

# --- ССЫЛКИ НА НОДЫ (Используем уникальные имена нод через %) ---
@onready var hit_button: Button = %HitButton
@onready var stand_button: Button = %StandButton
@onready var turn_timer: Timer = $TurnTimer
@onready var results_screen: Control = %ResultsScreen
@onready var winner_text: Label = %WinnerText

# Ссылки на контейнеры игроков
@onready var players = [
	$PlayersContainer/Player_0_Human,
	$PlayersContainer/Player_1_Bot,
	$PlayersContainer/Player_2_Bot,
	$PlayersContainer/Player_3_Bot
]

# --- ДАННЫЕ ИГРЫ ---
var deck: Array[GameCard] = [] # Наша колода карт
var hands: Array[Array] = [[], [], [], []] # Карты в руках 4 игроков [[Card, Card], [...]]
var current_player_index: int = 0 # Чей сейчас ход (0 - игрок, 1-3 - боты)
var active_players: Array[bool] = [true, true, true, true] # Кто еще не пасанул и не вылетел

# Масти и ранги для колоды из 36 карт
const SUITS = [Suit.SPADES, Suit.CLUBS, Suit.DIAMONDS, Suit.HEARTS]
const RANKS = {
	"6": 6, "7": 7, "8": 8, "9": 9, "10": 10,
	"Jack": 2, "Queen": 3, "King": 4, "Ace": 11
}

func _ready() -> void:
	randomize() # Инициализируем случайные числа
	
	# Безопасно подключаем сигналы кнопок (проверяем, что они созданы в HUD)
	if hit_button: hit_button.pressed.connect(_on_hit_pressed)
	if stand_button: stand_button.pressed.connect(_on_stand_pressed)
	if %RestartButton: %RestartButton.pressed.connect(start_new_round)
	if turn_timer: turn_timer.timeout.connect(process_bot_turn)
	
	start_new_round()

# --- ЛОГИКА КОЛОДЫ ---
func generate_deck() -> void:
	deck.clear()
	for suit in SUITS:
		for rank in RANKS.keys():
			var new_card = GameCard.new()
			new_card.suit = suit
			new_card.rank = rank
			new_card.value = RANKS[rank]
			# Тут художники позже укажут путь к пиксель-арту:
			# new_card.texture = load("res://art/cards/" + rank + "_" + str(suit) + ".png")
			deck.append(new_card)

func shuffle_deck() -> void:
	deck.shuffle()

func draw_card() -> GameCard:
	if deck.size() == 0:
		generate_deck()
		shuffle_deck()
	return deck.pop_back()

func calculate_score(hand: Array) -> int:
	# Правило "Два Туза" — автоматическое 21
	if hand.size() == 2 and hand[0].rank == "Ace" and hand[1].rank == "Ace":
		return 21
		
	var total = 0
	for card in hand:
		total += card.value
	return total

# --- ИГРОВОЙ ПРОЦЕСС ---
func start_new_round() -> void:
	if results_screen: results_screen.hide()
	generate_deck()
	shuffle_deck()
	
	hands = [[], [], [], []]
	active_players = [true, true, true, true]
	current_player_index = 0
	
	for i in range(4):
		clear_hand_visuals(i)
		give_card(i)
		give_card(i)
		
	start_turn()

func give_card(player_idx: int) -> void:
	var card = draw_card()
	hands[player_idx].append(card)
	
	# Визуально добавляем карту на стол в HBoxContainer игрока
	var card_sprite = TextureRect.new()
	card_sprite.texture = card.texture
	card_sprite.custom_minimum_size = Vector2(80, 120) # Размер карты на экране
	card_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	
	var hand_container = players[player_idx].get_node("CardsHand")
	if hand_container:
		hand_container.add_child(card_sprite)
	
	# Считаем очки
	var score = calculate_score(hands[player_idx])
	var score_label = players[player_idx].get_node("ScoreLabel")
	
	if score_label:
		if score > 21:
			active_players[player_idx] = false
			score_label.text = "Перебор! (" + str(score) + ")"
		else:
			score_label.text = "Очки: " + str(score)

func start_turn() -> void:
	if not active_players.has(true):
		end_game()
		return
		
	if not active_players[current_player_index]:
		next_turn()
		return
		
	if current_player_index == 0:
		if hit_button: hit_button.disabled = false
		if stand_button: stand_button.disabled = false
	else:
		if hit_button: hit_button.disabled = true
		if stand_button: stand_button.disabled = true
		if turn_timer: turn_timer.start(1.5) # Пауза, пока бот "думает"

func next_turn() -> void:
	current_player_index = (current_player_index + 1) % 4
	start_turn()

func process_bot_turn() -> void:
	var bot_idx = current_player_index
	var current_score = calculate_score(hands[bot_idx])
	
	if current_score < 16:
		give_card(bot_idx)
		if active_players[bot_idx]:
			if turn_timer: turn_timer.start(1.2)
		else:
			next_turn()
	else:
		active_players[bot_idx] = false
		next_turn()

func _on_hit_pressed() -> void:
	give_card(0)
	if not active_players[0]:
		if hit_button: hit_button.disabled = true
		if stand_button: stand_button.disabled = true
		next_turn()

func _on_stand_pressed() -> void:
	active_players[0] = false
	next_turn()

func end_game() -> void:
	if hit_button: hit_button.disabled = true
	if stand_button: stand_button.disabled = true
	
	var best_score = -1
	var winner_idx = -1
	
	for i in range(4):
		var score = calculate_score(hands[i])
		if score <= 21 and score > best_score:
			best_score = score
			winner_idx = i
			
	if winner_text:
		if winner_idx == -1:
			winner_text.text = "Все перебрали! Ничья."
		elif winner_idx == 0:
			winner_text.text = "Вы победили с результатом: " + str(best_score) + "!"
		else:
			winner_text.text = "Победил Бот " + str(winner_idx) + " с результатом: " + str(best_score)
		
	if results_screen: results_screen.show()

func clear_hand_visuals(player_idx: int) -> void:
	var hand_container = players[player_idx].get_node("CardsHand")
	if hand_container:
		for child in hand_container.get_children():
			child.queue_free()
