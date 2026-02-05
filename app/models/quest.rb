# frozen_string_literal: true

class Quest < ApplicationRecord
  include TripleId

  # Galaxy constants
  GALAXIES = %w[rusty_belt neon_spire void_lab the_hive].freeze

  # Galaxy → Race mapping
  CONTROLLING_RACES = {
    "rusty_belt" => "krog",
    "neon_spire" => "vex",
    "void_lab" => "solari",
    "the_hive" => "myrmidon"
  }.freeze

  # Galaxy themes
  THEMES = {
    "rusty_belt" => "Industrial",
    "neon_spire" => "Corporate",
    "void_lab" => "Scientific",
    "the_hive" => "Biological"
  }.freeze

  # NPC Guides per galaxy
  NPC_GUIDES = {
    "rusty_belt" => {
      name: "Foreman Zorg",
      race: "krog",
      traits: ["Aggressive", "Loud", "Impatient"]
    },
    "neon_spire" => {
      name: "Broker Sly",
      race: "vex",
      traits: ["Whispering", "Nervous", "Greedy"]
    },
    "void_lab" => {
      name: "Lead Researcher 7-Alpha",
      race: "solari",
      traits: ["Literal", "Emotionless"]
    },
    "the_hive" => {
      name: "Cluster 8",
      race: "myrmidon",
      traits: ["Plural", "Hungry"]
    }
  }.freeze

  # Quest definitions per galaxy
  QUEST_DATA = {
    "rusty_belt" => [
      {
        name: "The Coffee Run",
        sequence: 1,
        context: "The cafeteria droid broke. The workers are rioting. I need Caffeine Sludge NOW!",
        task: "Travel to Sector-9, buy 10 tons of Bio-Waste, refine it into Caffeine.",
        mechanics_taught: ["movement", "trading", "refining"],
        credits_reward: 150
      },
      {
        name: "Smash the Competitor",
        sequence: 2,
        context: "A drone is scanning MY asteroid. Go scare it off! CRUSH IT!",
        task: "Engage and destroy the weak NPC drone in combat.",
        mechanics_taught: ["combat", "looting"],
        credits_reward: 500
      }
    ],
    "neon_spire" => [
      {
        name: "Tax Evasion",
        sequence: 1,
        context: "Keep this between us... The auditors are coming. I need to hide this 'undeclared cargo' off-planet.",
        task: "Move 5 tons of Luxury Goods to a hidden moon before the timer expires (10 minutes).",
        mechanics_taught: ["movement", "cargo_management", "timed_delivery"],
        credits_reward: 200
      },
      {
        name: "The Insider Tip",
        sequence: 2,
        context: "I heard minerals are cheap in Sector-4. Go buy them all before the market realizes. This stays quiet.",
        task: "Buy Low in System A, Sell High in System B for profit.",
        mechanics_taught: ["trading", "arbitrage", "market_analysis"],
        credits_reward: 750
      }
    ],
    "void_lab" => [
      {
        name: "Data Collection",
        sequence: 1,
        context: "We require data on the mating habits of space whales. Do not ask why. Probability of relevance: 47.3%.",
        task: "Equip a Scanner, travel to Deep Space Node X, perform a scan.",
        mechanics_taught: ["movement", "scanning", "modules"],
        credits_reward: 175
      },
      {
        name: "The Gate Test",
        sequence: 2,
        context: "We have constructed a prototype gate. Test it. Calculate: probability of atomization is only 4%.",
        task: "Use a Warp Gate to travel to a distant node and return.",
        mechanics_taught: ["warp_gates", "navigation", "fuel_management"],
        credits_reward: 600
      }
    ],
    "the_hive" => [
      {
        name: "Feeding Time",
        sequence: 1,
        context: "We are hungry. The Larvae are hungry. The nutrient paste is depleted. We require sustenance.",
        task: "Mine Ice from a nearby belt and convert it to Water.",
        mechanics_taught: ["movement", "mining", "resource_conversion"],
        credits_reward: 125
      },
      {
        name: "Expand the Colony",
        sequence: 2,
        context: "We require more space. The Hive must grow. Deliver these construction drones. We wait.",
        task: "Transport Drone Parts to a construction site and build a Habitat.",
        mechanics_taught: ["cargo_transport", "construction", "buildings"],
        credits_reward: 650
      }
    ]
  }.freeze

  # Associations
  has_many :quest_progresses, dependent: :destroy
  has_many :users, through: :quest_progresses

  # Validations
  validates :name, presence: true
  validates :short_id, presence: true, uniqueness: true
  validates :galaxy, presence: true, inclusion: { in: GALAXIES }
  validates :sequence, presence: true, inclusion: { in: [1, 2] }
  validates :galaxy, uniqueness: { scope: :sequence }

  # Callbacks
  before_validation :generate_short_id, on: :create

  # ===========================================
  # Class Methods - Galaxy Data Lookups
  # ===========================================

  # Returns the controlling race for a galaxy
  # @param galaxy [String] Galaxy identifier
  # @return [String] Race name
  def self.controlling_race(galaxy)
    CONTROLLING_RACES[galaxy]
  end

  # Returns the theme for a galaxy
  # @param galaxy [String] Galaxy identifier
  # @return [String] Theme description
  def self.theme(galaxy)
    THEMES[galaxy]
  end

  # Returns the NPC guide data for a galaxy
  # @param galaxy [String] Galaxy identifier
  # @return [Hash] Guide data with :name, :race, :traits
  def self.npc_guide(galaxy)
    NPC_GUIDES[galaxy]
  end

  # Returns quests for a specific galaxy, creating them if needed
  # @param galaxy [String] Galaxy identifier
  # @return [Array<Quest>] Array of 2 Quest objects
  def self.for_galaxy(galaxy)
    return [] unless GALAXIES.include?(galaxy)

    quests = where(galaxy: galaxy).order(:sequence).to_a

    # Create quests if they don't exist
    if quests.empty?
      QUEST_DATA[galaxy].each do |quest_attrs|
        quests << create!(quest_attrs.merge(galaxy: galaxy))
      end
    end

    quests
  end

  # ===========================================
  # Instance Methods - Quest Content
  # ===========================================

  # Returns the NPC dialogue for this quest with racial personality
  # @return [String] Formatted dialogue
  def npc_dialogue
    guide = NPC_GUIDES[galaxy]
    base_context = context.dup

    case guide[:race]
    when "krog"
      # Aggressive, loud - use exclamations and demanding tone
      format_krog_dialogue(base_context)
    when "vex"
      # Whispering, nervous, greedy - conspiratorial tone
      format_vex_dialogue(base_context)
    when "solari"
      # Literal, emotionless - clinical and precise
      format_solari_dialogue(base_context)
    when "myrmidon"
      # Plural pronouns, hungry - collective voice
      format_myrmidon_dialogue(base_context)
    else
      base_context
    end
  end

  private

  def generate_short_id
    return if short_id.present?

    base = "q-#{name[0, 3].downcase}" if name.present?
    base ||= "q-#{SecureRandom.hex(3)}"
    candidate = base
    counter = 2

    while Quest.exists?(short_id: candidate)
      candidate = "#{base}#{counter}"
      counter += 1
    end

    self.short_id = candidate
  end

  def format_krog_dialogue(text)
    # Krog: aggressive, uses exclamations, demands action
    "#{text.upcase.gsub(/\.$/, '!')} GET IT DONE NOW!"
  end

  def format_vex_dialogue(text)
    # Vex: whispering, conspiratorial
    "Keep this quiet... #{text} ...this stays between us."
  end

  def format_solari_dialogue(text)
    # Solari: clinical, probability-focused
    "Data required. #{text} Calculate probability of success before proceeding."
  end

  def format_myrmidon_dialogue(text)
    # Myrmidon: plural pronouns, replace I with We
    text.gsub(/\bI\b/, "We").gsub(/\bmy\b/i, "our").gsub(/\bme\b/i, "us")
  end
end
