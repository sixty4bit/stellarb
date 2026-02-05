# frozen_string_literal: true

require "test_helper"

class EmigrationControllerTest < ActionDispatch::IntegrationTest
  setup do
    @suffix = SecureRandom.hex(4)

    # Create a user in emigration phase
    @user = User.create!(
      name: "Emigrant",
      email: "emigrant-#{@suffix}@test.example",
      short_id: "u-emi-#{@suffix}",
      level_tier: 1,
      credits: 10_000,
      tutorial_phase: :emigration  # Phase 3 - ready to emigrate
    )

    # Create hub owners
    @hub_owners = 5.times.map do |i|
      User.create!(
        name: "Hub Owner #{i}",
        email: "hubowner#{i}-#{@suffix}@test.example",
        short_id: "u-hub#{i}-#{@suffix}",
        credits: 100_000
      )
    end

    # Create systems for hubs
    @hub_systems = 5.times.map do |i|
      System.create!(
        name: "Hub System #{i} #{@suffix}",
        x: rand(300_000..700_000),
        y: rand(300_000..700_000),
        z: rand(300_000..700_000),
        short_id: "sy-hub#{i}-#{@suffix}",
        properties: {
          "star_type" => "yellow_dwarf",
          "planet_count" => rand(2..8),
          "base_prices" => {
            "fuel" => rand(80..120),
            "food" => rand(40..60)
          }
        }
      )
    end

    # Create certified player hubs
    @hubs = 5.times.map do |i|
      PlayerHub.create!(
        owner: @hub_owners[i],
        system: @hub_systems[i],
        security_rating: 50 + i * 10,  # 50, 60, 70, 80, 90
        economic_liquidity: 5_000 + i * 1_000,
        active_buy_orders: 10 + i * 5,
        tax_rate: 5,
        certified: true,
        certified_at: 1.week.ago
      )
    end
  end

  # ===========================================
  # Index Action Tests
  # ===========================================

  test "index requires authentication" do
    get emigration_path
    assert_redirected_to new_session_path
  end

  test "index shows emigration screen for emigration phase user" do
    sign_in_as(@user)

    get emigration_path
    assert_response :success
    assert_select "h2", text: /The Emigration/i
  end

  test "index shows 5 hub dossiers" do
    sign_in_as(@user)

    get emigration_path
    assert_response :success
    # Should show 5 hub options
    assert_select ".hub-dossier", count: 5
  end

  test "index shows hub details in each dossier" do
    sign_in_as(@user)

    get emigration_path
    assert_response :success

    # Each dossier should contain key info
    assert_select ".hub-dossier" do |dossiers|
      dossiers.each do |dossier|
        assert_select dossier, ".owner-name"
        assert_select dossier, ".system-name"
        assert_select dossier, ".security-level"
        assert_select dossier, ".tax-rate"
      end
    end
  end

  test "index redirects graduated users to root" do
    @user.update!(tutorial_phase: :graduated)
    sign_in_as(@user)

    get emigration_path
    assert_redirected_to root_path
    assert_match /already emigrated/i, flash[:alert]
  end

  test "index redirects cradle phase users to root" do
    @user.update!(tutorial_phase: :cradle)
    sign_in_as(@user)

    get emigration_path
    assert_redirected_to root_path
    assert_match /not ready/i, flash[:alert]
  end

  test "index shows selection form for each hub" do
    sign_in_as(@user)

    get emigration_path
    assert_response :success

    # Each hub should have a select button/form
    assert_select "form[action=?]", emigration_path, count: 5
  end

  # ===========================================
  # Create Action Tests (Hub Selection)
  # ===========================================

  test "create requires authentication" do
    post emigration_path, params: { hub_id: @hubs.first.id }
    assert_redirected_to new_session_path
  end

  test "create requires emigration phase" do
    @user.update!(tutorial_phase: :cradle)
    sign_in_as(@user)

    post emigration_path, params: { hub_id: @hubs.first.id }
    assert_redirected_to root_path
    assert_match /not ready/i, flash[:alert]
  end

  test "create with valid hub_id completes emigration" do
    sign_in_as(@user)
    hub = @hubs.first

    post emigration_path, params: { hub_id: hub.id }

    @user.reload
    assert @user.graduated?
    assert @user.emigrated?
    assert_equal hub.id, @user.emigration_hub_id
    assert_not_nil @user.emigrated_at
  end

  test "create increments hub immigration count" do
    sign_in_as(@user)
    hub = @hubs.first
    original_count = hub.immigration_count

    post emigration_path, params: { hub_id: hub.id }

    hub.reload
    assert_equal original_count + 1, hub.immigration_count
  end

  test "create redirects to new home system" do
    sign_in_as(@user)
    hub = @hubs.first

    post emigration_path, params: { hub_id: hub.id }

    assert_redirected_to root_path
    assert_match /Welcome to #{hub.system.name}/i, flash[:notice]
  end

  test "create with invalid hub_id shows error" do
    sign_in_as(@user)

    post emigration_path, params: { hub_id: 999_999 }

    assert_response :unprocessable_entity
    assert_match /Invalid hub selection/i, flash[:alert]
  end

  test "create with uncertified hub_id shows error" do
    sign_in_as(@user)

    # Create an uncertified hub
    uncertified_system = System.create!(
      name: "Uncertified #{@suffix}",
      x: rand(300_000..700_000),
      y: rand(300_000..700_000),
      z: rand(300_000..700_000),
      short_id: "sy-unc-#{@suffix}",
      properties: { "star_type" => "red_dwarf" }
    )
    uncertified_owner = User.create!(
      name: "Uncertified Owner",
      email: "uncert-#{@suffix}@test.example",
      short_id: "u-unc-#{@suffix}"
    )
    uncertified_hub = PlayerHub.create!(
      owner: uncertified_owner,
      system: uncertified_system,
      security_rating: 50,
      certified: false
    )

    post emigration_path, params: { hub_id: uncertified_hub.id }

    assert_response :unprocessable_entity
    assert_match /Invalid hub selection/i, flash[:alert]
  end

  test "emigration can only happen once" do
    sign_in_as(@user)
    hub = @hubs.first

    # First emigration succeeds
    post emigration_path, params: { hub_id: hub.id }
    assert_redirected_to root_path

    # Second attempt fails
    post emigration_path, params: { hub_id: @hubs.second.id }
    assert_redirected_to root_path
    assert_match /already emigrated/i, flash[:alert]
  end
end
