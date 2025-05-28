// Listen to the biome tag event
ServerEvents.tags('worldgen/biome', event => {
  event.remove('minecraft:is_forest', 'regions_unexplored:alpha_grove')
})
