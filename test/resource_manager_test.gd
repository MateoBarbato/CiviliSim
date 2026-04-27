## Test de ResourceManager

extends GdUnitTestSuite

var resource_manager: Node

func before_test() -> void:
	resource_manager = ResourceManager


func test_initial_resources() -> void:
	assert_that(resource_manager.food).is_equal(50.0)
	assert_that(resource_manager.wood).is_equal(20.0)
	assert_that(resource_manager.stone).is_equal(10.0)


func test_add_food() -> void:
	resource_manager.reset()
	resource_manager.add_food(30.0)
	assert_that(resource_manager.food).is_equal(80.0)


func test_add_food_respects_max() -> void:
	resource_manager.reset()
	resource_manager.add_food(500.0)
	assert_that(resource_manager.food).is_equal(500.0)


func test_remove_food() -> void:
	resource_manager.reset()
	var success = resource_manager.remove_food(20.0)
	assert_that(success).is_true()
	assert_that(resource_manager.food).is_equal(30.0)


func test_remove_food_fails_when_insufficient() -> void:
	resource_manager.reset()
	var success = resource_manager.remove_food(999.0)
	assert_that(success).is_false()
	assert_that(resource_manager.food).is_equal(50.0)


func test_has_enough_for_shelter() -> void:
	resource_manager.reset()
	resource_manager.add_wood(10.0)
	resource_manager.add_stone(5.0)
	assert_that(resource_manager.has_enough_for_shelter()).is_true()


func test_consume_shelter_cost() -> void:
	resource_manager.reset()
	resource_manager.add_wood(10.0)
	resource_manager.add_stone(5.0)
	var success = resource_manager.consume_shelter_cost()
	assert_that(success).is_true()
	assert_that(resource_manager.wood).is_equal(15.0)
	assert_that(resource_manager.stone).is_equal(10.0)


func test_resource_state_returns_dictionary() -> void:
	resource_manager.reset()
	var state = resource_manager.get_resource_state()
	assert_that(state).is_not_null()
	assert_that(state.has("food")).is_true()
	assert_that(state.has("wood")).is_true()
	assert_that(state.has("stone")).is_true()
	assert_that(state.has("food_percent")).is_true()


func test_reset_restores_initial_values() -> void:
	resource_manager.food = 0.0
	resource_manager.wood = 0.0
	resource_manager.stone = 0.0
	resource_manager.reset()
	assert_that(resource_manager.food).is_equal(50.0)
	assert_that(resource_manager.wood).is_equal(20.0)
	assert_that(resource_manager.stone).is_equal(10.0)


func test_resource_percentages_are_correct() -> void:
	resource_manager.reset()
	var state = resource_manager.get_resource_state()
	assert_that(state["food_percent"]).is_equal(10.0)
	assert_that(state["wood_percent"]).is_greater(6.0)
	assert_that(state["wood_percent"]).is_less(7.0)
	assert_that(state["stone_percent"]).is_equal(5.0)
