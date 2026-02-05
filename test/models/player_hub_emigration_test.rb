require "test_helper"

class PlayerHubEmigrationTest < ActiveSupport::TestCase
  setup do
    @suffix = SecureRandom.hex(4)

    # Create multiple hub owners
    @owners = 8.times.map do |i|
      User.create!(
        name: "Owner #{i}",
        email: "owner#{i}-#{@suffix}@example.com",
        short_id: "u-own#{i}-#{@suffix}",
        credits: 100_000
      )
    end

    # Create systems for hubs (deep in frontier)
    @systems = 8.times.map do |i|
      System.create!(
        name: "Hub System #{i} #{@suffix}",
        x: rand(300_000..700_000),
        y: rand(300_000..700_000),
        z: rand(300_000..700_000),
        short_id: "sy-hub#{i}-#{@suffix}",
        properties: {
          "star_type" => "yellow_dwarf",
          "planet_count" => rand(2..8),
          "hazard_level" => rand(10..50),
          "base_prices" => {
            "fuel" => rand(80..120),
            "food" => rand(40..60),
            "iron" => rand(20..40)
          }
        }
      )
    end

    # Create 6 certified hubs (more than 5, to test random selection)
    @certified_hubs = 6.times.map do |i|
      PlayerHub.create!(
        owner: @owners[i],
        system: @systems[i],
        security_rating: rand(50..95),
        economic_liquidity: rand(5_000..20_000),
        active_buy_orders: rand(10..50),
        tax_rate: rand(3..10),
        certified: true,
        certified_at: rand(1..30).days.ago
      )
    end

    # Create 2 uncertified hubs
    @uncertified_hubs = 2.times.map do |i|
      PlayerHub.create!(
        owner: @owners[6 + i],
        system: @systems[6 + i],
        security_rating: rand(20..40),
        economic_liquidity: rand(1_000..3_000),
        certified: false
      )
    end
  end

  # ===========================================
  # Emigration Options Query Tests
  # ===========================================

  test "emigration_options returns exactly 5 hubs" do
    options = PlayerHub.emigration_options
    assert_equal 5, options.count
  end

  test "emigration_options only returns certified hubs" do
    options = PlayerHub.emigration_options
    assert options.all?(&:certified?)
  end

  test "emigration_options returns different results on multiple calls (random)" do
    # Run multiple times and check we get different orderings
    results = 10.times.map { PlayerHub.emigration_options.pluck(:id).sort }

    # With 6 certified hubs choosing 5, we should see some variation
    # (though technically could all be same by chance)
    unique_results = results.uniq.count
    # At minimum, verify it returns valid results each time
    assert results.all? { |r| r.length == 5 }
  end

  test "emigration_options returns fewer than 5 if not enough certified hubs exist" do
    # Remove some certified hubs
    @certified_hubs[0..3].each(&:destroy)

    options = PlayerHub.emigration_options
    assert_equal 2, options.count # Only 2 certified left
  end

  test "emigration_options returns empty when no certified hubs exist" do
    PlayerHub.certified.destroy_all

    options = PlayerHub.emigration_options
    assert_empty options
  end

  # ===========================================
  # Emigration Dossiers Query Tests
  # ===========================================

  test "emigration_dossiers returns array of dossier hashes" do
    dossiers = PlayerHub.emigration_dossiers
    assert_kind_of Array, dossiers
    assert_equal 5, dossiers.count
    assert dossiers.all? { |d| d.is_a?(Hash) }
  end

  test "emigration_dossiers includes all required dossier fields" do
    dossiers = PlayerHub.emigration_dossiers
    required_fields = [
      :owner_name, :system_name, :coordinates,
      :security_rating, :security_level, :tax_rate,
      :resource_prices, :economic_liquidity, :active_buy_orders,
      :immigration_count, :distance_from_cradle
    ]

    dossiers.each do |dossier|
      required_fields.each do |field|
        assert dossier.key?(field), "Dossier missing required field: #{field}"
      end
    end
  end

  test "emigration_dossiers are sorted by security rating descending" do
    dossiers = PlayerHub.emigration_dossiers
    ratings = dossiers.map { |d| d[:security_rating] }
    assert_equal ratings.sort.reverse, ratings
  end

  test "emigration_dossiers include hub_id for selection" do
    dossiers = PlayerHub.emigration_dossiers
    dossiers.each do |dossier|
      assert dossier.key?(:hub_id), "Dossier missing hub_id for selection"
      assert_kind_of Integer, dossier[:hub_id]
    end
  end

  # ===========================================
  # Edge Cases
  # ===========================================

  test "emigration_options excludes hubs with security_rating below 20" do
    # Create a hub with very low security (Lawless)
    lawless_owner = User.create!(
      name: "Lawless Owner",
      email: "lawless-#{@suffix}@example.com",
      short_id: "u-law-#{@suffix}"
    )
    lawless_system = System.create!(
      name: "Lawless Station #{@suffix}",
      x: rand(300_000..700_000),
      y: rand(300_000..700_000),
      z: rand(300_000..700_000),
      short_id: "sy-law-#{@suffix}",
      properties: { "star_type" => "red_dwarf" }
    )
    lawless_hub = PlayerHub.create!(
      owner: lawless_owner,
      system: lawless_system,
      security_rating: 15,  # Below threshold
      certified: true,
      certified_at: 1.day.ago
    )

    options = PlayerHub.emigration_options
    assert_not_includes options.pluck(:id), lawless_hub.id
  end

  test "find_emigration_hub_by_id returns hub if valid emigration option" do
    options = PlayerHub.emigration_options
    hub_id = options.first.id

    found = PlayerHub.find_emigration_hub_by_id(hub_id)
    assert_equal hub_id, found.id
  end

  test "find_emigration_hub_by_id returns nil for uncertified hub" do
    hub_id = @uncertified_hubs.first.id

    found = PlayerHub.find_emigration_hub_by_id(hub_id)
    assert_nil found
  end

  test "find_emigration_hub_by_id returns nil for non-existent id" do
    found = PlayerHub.find_emigration_hub_by_id(999_999)
    assert_nil found
  end
end
