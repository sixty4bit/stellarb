require "test_helper"

class PlayerHubTest < ActiveSupport::TestCase
  setup do
    @suffix = SecureRandom.hex(4)

    @owner = User.create!(
      name: "Hub Owner",
      email: "owner-#{@suffix}@example.com",
      short_id: "u-own-#{@suffix}",
      credits: 100_000
    )

    # Create a system for the hub (deep in frontier)
    @x = rand(400_000..600_000)
    @y = rand(400_000..600_000)
    @z = rand(400_000..600_000)

    @system = System.create!(
      name: "Alpha Prime #{@suffix}",
      x: @x,
      y: @y,
      z: @z,
      short_id: "sy-alp-#{@suffix}",
      properties: {
        "star_type" => "yellow_dwarf",
        "planet_count" => 4,
        "hazard_level" => 15,
        "base_prices" => {
          "fuel" => 100,
          "food" => 50,
          "iron" => 30,
          "water" => 20
        }
      }
    )

    @hub = PlayerHub.create!(
      owner: @owner,
      system: @system,
      security_rating: 85,
      economic_liquidity: 10_000,
      active_buy_orders: 25,
      tax_rate: 5,
      certified: true,
      certified_at: 3.days.ago
    )
  end

  # ===========================================
  # Basic Model Tests
  # ===========================================

  test "belongs to owner (user)" do
    assert_equal @owner, @hub.owner
  end

  test "belongs to system" do
    assert_equal @system, @hub.system
  end

  test "requires owner" do
    hub = PlayerHub.new(system: @system, security_rating: 50)
    assert_not hub.valid?
    assert_includes hub.errors[:owner], "must exist"
  end

  test "requires system" do
    hub = PlayerHub.new(owner: @owner, security_rating: 50)
    assert_not hub.valid?
    assert_includes hub.errors[:system], "must exist"
  end

  test "system can only have one hub" do
    duplicate = PlayerHub.new(
      owner: @owner,
      system: @system,
      security_rating: 50
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:system_id], "has already been taken"
  end

  # ===========================================
  # Certification Tests
  # ===========================================

  test "certified? returns true when certified" do
    assert @hub.certified?
  end

  test "certified? returns false when not certified" do
    @hub.update!(certified: false)
    assert_not @hub.certified?
  end

  test "certified scope returns only certified hubs" do
    # Use coordinates that won't trigger procedural generation validation
    other_x = rand(200_000..300_000)
    other_y = rand(200_000..300_000)
    other_z = rand(200_000..300_000)

    uncertified = PlayerHub.create!(
      owner: @owner,
      system: System.create!(
        name: "Beta #{@suffix}",
        x: other_x,
        y: other_y,
        z: other_z,
        short_id: "sy-bet-#{@suffix}",
        properties: { "star_type" => "red_dwarf", "planet_count" => 2 }
      ),
      security_rating: 30,
      certified: false
    )

    certified_hubs = PlayerHub.certified
    assert_includes certified_hubs, @hub
    assert_not_includes certified_hubs, uncertified
  end

  # ===========================================
  # Dossier Tests (Core Feature)
  # ===========================================

  test "dossier returns hub information hash" do
    dossier = @hub.dossier
    assert_kind_of Hash, dossier
  end

  test "dossier includes owner name" do
    dossier = @hub.dossier
    assert_equal "Hub Owner", dossier[:owner_name]
  end

  test "dossier includes system name" do
    dossier = @hub.dossier
    assert_equal @system.name, dossier[:system_name]
  end

  test "dossier includes security rating" do
    dossier = @hub.dossier
    assert_equal 85, dossier[:security_rating]
  end

  test "dossier includes security level description" do
    dossier = @hub.dossier
    assert_equal "High Security", dossier[:security_level]
  end

  test "dossier includes tax rate" do
    dossier = @hub.dossier
    assert_equal 5, dossier[:tax_rate]
  end

  test "dossier includes resource prices from system" do
    dossier = @hub.dossier
    assert_kind_of Hash, dossier[:resource_prices]
    assert_equal 100, dossier[:resource_prices]["fuel"]
    assert_equal 50, dossier[:resource_prices]["food"]
  end

  test "dossier includes economic indicators" do
    dossier = @hub.dossier
    assert_equal 10_000, dossier[:economic_liquidity]
    assert_equal 25, dossier[:active_buy_orders]
  end

  test "dossier includes immigration count" do
    @hub.update!(immigration_count: 42)
    dossier = @hub.dossier

    assert_equal 42, dossier[:immigration_count]
  end

  test "dossier includes system coordinates" do
    dossier = @hub.dossier
    assert_equal({ x: @x, y: @y, z: @z }, dossier[:coordinates])
  end

  test "dossier includes distance from cradle" do
    dossier = @hub.dossier
    # Distance from (0,0,0) to (@x, @y, @z)
    expected_distance = Math.sqrt(@x**2 + @y**2 + @z**2)
    assert_in_delta expected_distance, dossier[:distance_from_cradle], 1
  end

  # ===========================================
  # Security Level Classification
  # ===========================================

  test "security_level returns High Security for 80-100" do
    @hub.update!(security_rating: 85)
    assert_equal "High Security", @hub.security_level
  end

  test "security_level returns Moderate for 50-79" do
    @hub.update!(security_rating: 65)
    assert_equal "Moderate", @hub.security_level
  end

  test "security_level returns Low Security for 20-49" do
    @hub.update!(security_rating: 35)
    assert_equal "Low Security", @hub.security_level
  end

  test "security_level returns Lawless for 0-19" do
    @hub.update!(security_rating: 10)
    assert_equal "Lawless", @hub.security_level
  end

  # ===========================================
  # Immigration Tracking
  # ===========================================

  test "record_immigration! increments immigration count" do
    assert_equal 0, @hub.immigration_count
    @hub.record_immigration!
    assert_equal 1, @hub.reload.immigration_count
  end

  test "record_immigration! can be called multiple times" do
    3.times { @hub.record_immigration! }
    assert_equal 3, @hub.reload.immigration_count
  end
end
