class_name ShoppingEntry extends Resource

# You need to export three properties:
#
# 1. text: a string that represents the name of the item
@export_multiline var text: String = ""
# 2. amount: an integer that represents the amount of the item
@export var amount: int = 0
# 3. price: an integer that represents the price of the item
@export var price: int = 0
