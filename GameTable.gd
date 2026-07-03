extends Control

# --- СТРУКТУРА КАРТЫ (Внутренний класс) ---
enum Suit { SPADES, CLUBS, DIAMONDS, HEARTS }

class TableCard:
	var suit: Suit
	var rank: String
	var value: int
	var texture: Texture2D
	var face_up: bool = false # По умолчанию лежит рубашкой вверх

# --- ССЫЛКИ НА НОДЫ (Используем уникальные имена нод через %) ---
@onready var hit_button: Button = %HitButton
@onready var stand_button: Button = %StandButton
@onready var turn_timer: Timer = $TurnTimer
@onready var results_screen: Control = %ResultsScreen
@onready var winner_text: Label = %WinnerText
@onready var deck_anchor: Node2D = $DeckAnchor # Точка, откуда летят карты

# Ссылки на контейнеры игроков
@onready var players = [
	$PlayersContainer/Player_0_Human,
	$PlayersContainer/Player_1_Bot,
	$PlayersContainer/Player_2_Bot,
	$PlayersContainer/Player_3_Bot
]

# --- ДАННЫЕ ИГРЫ ---
var deck: Array[TableCard] = [] # Наша колода карт
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
	
	# Безопасно подключаем сигналы кнопок
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
			var new_card = TableCard.new()
			new_card.suit = suit
			new_card.rank = rank
			new_card.value = RANKS[rank]
			new_card.face_up = false # При создании все карты закрыты
			
			# Текстовое имя масти (SPADES, CLUBS и т.д.)
			var suit_name = Suit.keys()[suit] 
			
			# Склеиваем путь, например: "res://art/cards/Ace_DIAMONDS.png"
			var file_path = "res://art/cards/" + rank + "_" + suit_name + ".png"
			
			# Проверяем, существует ли файл карты
			if ResourceLoader.exists(file_path):
				new_card.texture = load(file_path)
			else:
				# Если файл не найден, временно подставим рубашку, чтобы игра не ломалась
				if ResourceLoader.exists("res://art/cards/card_back.png"):
					new_card.texture = load("res://art/cards/card_back.png")
				print("Предупреждение: Файл карты не найден: ", file_path)
				
			deck.append(new_card)

func shuffle_deck() -> void:
	deck.shuffle()

func draw_card() -> TableCard:
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
	
	# Очищаем визуальные карты на столе
	for i in range(4):
		clear_hand_visuals(i)
	
	# Раздаем по 2 начальные карты по очереди, как в реальной жизни
	for round_step in range(2):
		for i in range(4):
			give_card(i)
			await create_timer(0.2) # Небольшая пауза между раздачами для красоты
		
	start_turn()

func give_card(player_idx: int) -> void:
	var card = draw_card()
	hands[player_idx].append(card)
	
	# Игрок 0 (человек) видит свои карты лицом. Боты — рубашкой вверх.
	if player_idx == 0:
		card.face_up = true
	else:
		card.face_up = false
		
	# Создаем визуальный спрайт карты
	var card_sprite = TextureRect.new()
	card_sprite.custom_minimum_size = Vector2(80, 120) # Базовый размер на экране
	card_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card_sprite.size = Vector2(80, 120)
	
	# Назначаем нужную текстуру
	if card.face_up and card.texture:
		card_sprite.texture = card.texture
	else:
		card_sprite.texture = load("res://art/cards/card_back.png")
		
	# Сохраняем информацию о карте прямо в спрайт (пригодится для вскрытия в конце)
	card_sprite.set_meta("card_data", card)
	
	# --- АНИМАЦИЯ ПОЛЕТА С КАРТОЧНОЙ СТОПКИ ---
	add_child(card_sprite)
	
	# Позиция старта (из колоды). Если DeckAnchor нет, берется центр экрана
	var start_pos = deck_anchor.global_position if deck_anchor else get_viewport_rect().size / 2
	card_sprite.global_position = start_pos
	
	# Вычисляем финальную позицию внутри контейнера руки игрока
	var hand_container = players[player_idx].get_node("CardsHand")
	var target_pos = hand_container.global_position
	
	if hand_container.get_child_count() > 0:
		# Сдвигаем цель вправо на основе количества уже имеющихся карт
		target_pos.x += hand_container.get_child_count() * 25 
		
	# Запуск плавного движения
	var tween = create_tween().set_parallel(true)
	tween.tween_property(card_sprite, "global_position", target_pos, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	card_sprite.scale = Vector2(0.4, 0.4)
	tween.tween_property(card_sprite, "scale", Vector2(1.0, 1.0), 0.35)
	
	# Ждем, пока карта физически долетит до места
	await create_timer(0.35)
	
	# Перекладываем ноду из общего стола внутрь контейнера руки, чтобы Godot сам держал их в ряд
	remove_child(card_sprite)
	hand_container.add_child(card_sprite)
	card_sprite.position = Vector2.ZERO # Сброс локальных координат
	card_sprite.scale = Vector2.ONE
	
	# Считаем очки
	var score = calculate_score(hands[player_idx])
	var score_label = players[player_idx].get_node("ScoreLabel")
	
	if score_label:
		if player_idx == 0:
			if score > 21:
				active_players[player_idx] = false
				score_label.text = "Перебор! (" + str(score) + ")"
			else:
				score_label.text = "Очки: " + str(score)
		else:
			# Для ботов скрываем точные очки во время матча, показываем только количество карт
			if score > 21:
				active_players[player_idx] = false
				score_label.text = "Выбыл"
			else:
				score_label.text = "Карт: " + str(hands[player_idx].size())

func start_turn() -> void:
	# Если вообще все выбыли или пасанули — завершаем игру
	if not active_players.has(true):
		end_game()
		return
		
	# Если текущий игрок уже пасанул, сразу передаем ход дальше
	if not active_players[current_player_index]:
		next_turn()
		return
		
	if current_player_index == 0:
		if hit_button: hit_button.disabled = false
		if stand_button: stand_button.disabled = false
	else:
		if hit_button: hit_button.disabled = true
		if stand_button: stand_button.disabled = true
		if turn_timer: turn_timer.start(1.5) # Бот "думает" полторы секунды

func next_turn() -> void:
	current_player_index = (current_player_index + 1) % 4
	start_turn()

func process_bot_turn() -> void:
	var bot_idx = current_player_index
	var current_score = calculate_score(hands[bot_idx])
	
	# ИИ: Берет карту, если набрал меньше 16 очков
	if current_score < 16:
		give_card(bot_idx)
		await create_timer(0.4) # Даем время долететь карте перед следующим решением
		
		if active_players[bot_idx]:
			if turn_timer: turn_timer.start(1.2)
		else:
			next_turn()
	else:
		active_players[bot_idx] = false # Бот решил остановиться
		next_turn()

func _on_hit_pressed() -> void:
	give_card(0)
	await create_timer(0.4)
	if not active_players[0]: # Если у игрока перебор
		if hit_button: hit_button.disabled = true
		if stand_button: stand_button.disabled = true
		next_turn()

func _on_stand_pressed() -> void:
	active_players[0] = false # Игрок пасует
	next_turn()

func end_game() -> void:
	if hit_button: hit_button.disabled = true
	if stand_button: stand_button.disabled = true
	
	# --- ВСКРЫТИЕ КАРТ ВСЕХ БОТОВ ---
	for i in range(1, 4):
		var hand_container = players[i].get_node("CardsHand")
		var score_label = players[i].get_node("ScoreLabel")
		
		var final_score = calculate_score(hands[i])
		if score_label:
			score_label.text = "Очки: " + str(final_score)
			if final_score > 21:
				score_label.text += " (Перебор)"

		# Эффектный переворот карт ботов лицом вверх
		for card_sprite in hand_container.get_children():
			if card_sprite.has_meta("card_data"):
				var card_data = card_sprite.get_meta("card_data")
				if card_data.texture:
					card_sprite.texture = card_data.texture # Меняем рубашку на пиксельное лицо карты
	
	# Находим победителя (у кого больше всех очков, но не больше 21)
	var best_score = -1
	var winner_idx = -1
	
	for i in range(4):
		var score = calculate_score(hands[i])
		if score <= 21 and score > best_score:
			best_score = score
			winner_idx = i
			
	# Выводим имя победителя
	if winner_text:
		if winner_idx == -1:
			winner_text.text = "Все перебрали! Ничья за столом."
		elif winner_idx == 0:
			winner_text.text = "Вы победили таверну с результатом: " + str(best_score) + "!"
		else:
			winner_text.text = "Победил Бот " + str(winner_idx) + " с результатом: " + str(best_score)
		
	if results_screen: results_screen.show()

func clear_hand_visuals(player_idx: int) -> void:
	var hand_container = players[player_idx].get_node("CardsHand")
	if hand_container:
		for child in hand_container.get_children():
			child.queue_free()

# Вспомогательная функция для чистых задержек в Godot 4
func create_timer(time: float) -> Signal:
	return get_tree().create_timer(time).timeout
