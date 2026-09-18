extends Node
## Global event log bus. Autoloaded as "MessageBus".
## UI (MessageLog) subscribes to message_logged to render a scrolling combat/event log.

signal message_logged(text: String)

func log_message(text: String) -> void:
	message_logged.emit(text)
	print(text)
