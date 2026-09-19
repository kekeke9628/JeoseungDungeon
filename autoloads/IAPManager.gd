extends Node
## In-app purchase state and product catalog. Autoloaded as "IAPManager".
##
## The store backend is intentionally a seam: purchase() only completes when a
## backend is available. Today that is the debug-build mock (OS.is_debug_build),
## so a release build without a real billing plugin fails closed instead of
## handing out paid items. Wire a real provider (Google Play Billing / StoreKit)
## into _request_store_purchase() and call _grant() only after the store confirms
## (and, before shipping, after server-side receipt verification).

signal purchase_completed(product_id: String)
signal purchase_failed(product_id: String, reason: String)
signal state_changed

const PRODUCTS: Dictionary = {
	"supporter_pack": {
		"name": "후원자 팩",
		"desc": "영구 적용: 매 판 저승꽃술 2개를 더 가지고 시작하고, 캐릭터에 황금빛 기운이 어린다.",
		"price": "₩3,300",
		"consumable": false,
	},
	"revive_token": {
		"name": "부활 부적",
		"desc": "쓰러졌을 때 체력 절반으로 되살아난다. 1회용.",
		"price": "₩1,100",
		"consumable": true,
	},
}
const SUPPORTER_BONUS_WINE: int = 2

## Overridable so tests never touch the player's real purchases.
var store_path: String = "user://purchases.json"
var supporter: bool = false
var revive_tokens: int = 0

func _ready() -> void:
	load_state()

func is_store_available() -> bool:
	return OS.is_debug_build()

func purchase(product_id: String) -> void:
	if not PRODUCTS.has(product_id):
		purchase_failed.emit(product_id, "알 수 없는 상품입니다.")
		return
	if not PRODUCTS[product_id].consumable and supporter:
		purchase_failed.emit(product_id, "이미 구매한 상품입니다.")
		return
	if not is_store_available():
		purchase_failed.emit(product_id, "스토어 결제가 아직 연결되지 않았습니다.")
		return
	_request_store_purchase(product_id)

func _request_store_purchase(product_id: String) -> void:
	# Debug-only mock: succeeds immediately. Replace with a real billing call.
	_grant(product_id)

func _grant(product_id: String) -> void:
	if PRODUCTS[product_id].consumable:
		revive_tokens += 1
	else:
		supporter = true
	save_state()
	state_changed.emit()
	purchase_completed.emit(product_id)

func consume_revive() -> bool:
	if revive_tokens <= 0:
		return false
	revive_tokens -= 1
	save_state()
	state_changed.emit()
	return true

func load_state() -> void:
	if not FileAccess.file_exists(store_path):
		return
	var f := FileAccess.open(store_path, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	supporter = bool(parsed.get("supporter", false))
	revive_tokens = maxi(0, int(parsed.get("revive_tokens", 0)))
	state_changed.emit()

func save_state() -> void:
	var f := FileAccess.open(store_path, FileAccess.WRITE)
	if f == null:
		push_warning("IAPManager: cannot write %s" % store_path)
		return
	f.store_string(JSON.stringify({"supporter": supporter, "revive_tokens": revive_tokens}))

func reset_for_tests() -> void:
	supporter = false
	revive_tokens = 0
	if FileAccess.file_exists(store_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(store_path))
