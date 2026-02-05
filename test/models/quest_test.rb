# frozen_string_literal: true

require "test_helper"

class QuestTest < ActiveSupport::TestCase
  # Galaxy constants
  test "defines four galaxies with unique themes" do
    assert_equal 4, Quest::GALAXIES.size
    assert_includes Quest::GALAXIES, "rusty_belt"
    assert_includes Quest::GALAXIES, "neon_spire"
    assert_includes Quest::GALAXIES, "void_lab"
    assert_includes Quest::GALAXIES, "the_hive"
  end

  test "each galaxy has a controlling race" do
    assert_equal "krog", Quest.controlling_race("rusty_belt")
    assert_equal "vex", Quest.controlling_race("neon_spire")
    assert_equal "solari", Quest.controlling_race("void_lab")
    assert_equal "myrmidon", Quest.controlling_race("the_hive")
  end

  test "each galaxy has a unique theme" do
    assert_equal "Industrial", Quest.theme("rusty_belt")
    assert_equal "Corporate", Quest.theme("neon_spire")
    assert_equal "Scientific", Quest.theme("void_lab")
    assert_equal "Biological", Quest.theme("the_hive")
  end

  # NPC Guides
  test "each galaxy has an NPC guide with name and personality" do
    guide = Quest.npc_guide("rusty_belt")
    assert_equal "Foreman Zorg", guide[:name]
    assert_equal "krog", guide[:race]
    assert_includes guide[:traits], "Aggressive"
    assert_includes guide[:traits], "Loud"
    assert_includes guide[:traits], "Impatient"
  end

  test "neon spire has Broker Sly as guide" do
    guide = Quest.npc_guide("neon_spire")
    assert_equal "Broker Sly", guide[:name]
    assert_equal "vex", guide[:race]
    assert_includes guide[:traits], "Whispering"
    assert_includes guide[:traits], "Nervous"
    assert_includes guide[:traits], "Greedy"
  end

  test "void lab has Lead Researcher 7-Alpha as guide" do
    guide = Quest.npc_guide("void_lab")
    assert_equal "Lead Researcher 7-Alpha", guide[:name]
    assert_equal "solari", guide[:race]
    assert_includes guide[:traits], "Literal"
    assert_includes guide[:traits], "Emotionless"
  end

  test "the hive has Cluster 8 as guide" do
    guide = Quest.npc_guide("the_hive")
    assert_equal "Cluster 8", guide[:name]
    assert_equal "myrmidon", guide[:race]
    assert_includes guide[:traits], "Plural"
    assert_includes guide[:traits], "Hungry"
  end

  # Quest Generation
  test "generates two quests per galaxy" do
    Quest::GALAXIES.each do |galaxy|
      quests = Quest.for_galaxy(galaxy)
      assert_equal 2, quests.size, "Expected 2 quests for #{galaxy}"
    end
  end

  test "quest 1 teaches basic mechanics" do
    quest = Quest.for_galaxy("rusty_belt").first
    assert_equal 1, quest.sequence
    assert_equal "The Coffee Run", quest.name
    assert_includes quest.mechanics_taught, "movement"
    assert_includes quest.mechanics_taught, "trading"
  end

  test "quest 2 teaches advanced mechanics per galaxy" do
    # Rusty Belt teaches combat
    quest = Quest.for_galaxy("rusty_belt").last
    assert_equal 2, quest.sequence
    assert_equal "Smash the Competitor", quest.name
    assert_includes quest.mechanics_taught, "combat"

    # Neon Spire teaches arbitrage
    quest = Quest.for_galaxy("neon_spire").last
    assert_includes quest.mechanics_taught, "arbitrage"

    # Void Lab teaches warp gates
    quest = Quest.for_galaxy("void_lab").last
    assert_includes quest.mechanics_taught, "warp_gates"

    # The Hive teaches construction
    quest = Quest.for_galaxy("the_hive").last
    assert_includes quest.mechanics_taught, "construction"
  end

  # Quest Details
  test "quests have context dialogue from NPC" do
    quest = Quest.for_galaxy("rusty_belt").first
    assert_match(/cafeteria droid broke/i, quest.context)
    assert_match(/Caffeine Sludge/i, quest.context)
  end

  test "quests have clear task descriptions" do
    quest = Quest.for_galaxy("rusty_belt").first
    assert_match(/Sector-9/i, quest.task)
    assert_match(/Bio-Waste/i, quest.task)
    assert_match(/Caffeine/i, quest.task)
  end

  # Quest Model Validations
  test "quest requires name" do
    quest = Quest.new(galaxy: "rusty_belt", sequence: 1)
    assert_not quest.valid?
    assert_includes quest.errors[:name], "can't be blank"
  end

  test "quest requires valid galaxy" do
    quest = Quest.new(name: "Test Quest", sequence: 1, galaxy: "invalid")
    assert_not quest.valid?
    assert_includes quest.errors[:galaxy], "is not included in the list"
  end

  test "quest requires sequence 1 or 2" do
    quest = Quest.new(name: "Test", galaxy: "rusty_belt", sequence: 3)
    assert_not quest.valid?
    assert_includes quest.errors[:sequence], "is not included in the list"
  end

  # Player Quest Progress
  test "user can start quest" do
    user = users(:pilot)
    quest = Quest.for_galaxy("rusty_belt").first

    progress = user.start_quest(quest)
    assert progress.persisted?
    assert_equal "in_progress", progress.status
    assert_not_nil progress.started_at
  end

  test "user can complete quest" do
    user = users(:pilot)
    quest = Quest.for_galaxy("rusty_belt").first

    progress = user.start_quest(quest)
    progress.complete!

    assert_equal "completed", progress.status
    assert_not_nil progress.completed_at
  end

  test "completing quest 1 unlocks quest 2" do
    user = users(:pilot)
    quest1 = Quest.for_galaxy("rusty_belt").first
    quest2 = Quest.for_galaxy("rusty_belt").last

    # Quest 2 locked initially
    assert_not user.can_start_quest?(quest2)

    # Complete quest 1
    progress = user.start_quest(quest1)
    progress.complete!

    # Quest 2 now available
    assert user.can_start_quest?(quest2)
  end

  test "quest rewards are sufficient to progress" do
    quest1 = Quest.for_galaxy("rusty_belt").first
    assert quest1.credits_reward >= 100, "Quest 1 should reward at least 100 credits"

    quest2 = Quest.for_galaxy("rusty_belt").last
    assert quest2.credits_reward >= 500, "Quest 2 should reward at least 500 credits"
  end

  # NPC Dialogue Personality
  test "krog npc dialogue is aggressive and loud" do
    quest = Quest.for_galaxy("rusty_belt").first
    dialogue = quest.npc_dialogue

    # Krog dialogue should be demanding and use exclamations
    assert_match(/!/, dialogue)
    assert_match(/NOW|NEED|GET/i, dialogue)
  end

  test "vex npc dialogue is whispering and nervous" do
    quest = Quest.for_galaxy("neon_spire").first
    dialogue = quest.npc_dialogue

    # Vex dialogue should be conspiratorial
    assert_match(/quiet|between us|secret|hide/i, dialogue)
  end

  test "solari npc dialogue is literal and emotionless" do
    quest = Quest.for_galaxy("void_lab").first
    dialogue = quest.npc_dialogue

    # Solari dialogue should be clinical
    assert_match(/require|data|probability|calculate/i, dialogue)
  end

  test "myrmidon npc dialogue uses plural pronouns" do
    quest = Quest.for_galaxy("the_hive").first
    dialogue = quest.npc_dialogue

    # Myrmidon uses "We" instead of "I"
    assert_match(/\bWe\b/, dialogue)
    assert_no_match(/\bI\b/, dialogue)
  end
end
