# frozen_string_literal: true

require "test_helper"

class ColonialTicketAutoUnlockTest < ActiveSupport::TestCase
  # The Colonial Ticket should be AUTOMATICALLY unlocked when Phase 2 is complete
  # (building constructed + system visited)
  # See ROADMAP.md Section 3.2 - "The Gate: Colonial Ticket unlocks after first building"

  setup do
    @user = User.create!(
      email: "prover@example.com",
      name: "Prover Test",
      tutorial_phase: :proving_ground,
      credits: 5000
    )
    @system = System.discover_at(x: 1, y: 0, z: 0, user: @user)
    @ship = Ship.create!(
      user: @user,
      name: "Builder Ship",
      hull_size: "transport",
      race: "krog",
      variant_idx: 1,
      fuel: 100,
      status: "docked",
      current_system: @system,
      cargo: { "iron" => 50, "silicon" => 30 }
    )
  end

  # ===========================================
  # Core Feature: Auto-unlock on building construction
  # ===========================================

  test "constructing first building auto-unlocks Colonial Ticket when scan complete" do
    # First, create a system visit (scan complete)
    create_system_visit

    # Construct a building - should auto-unlock ticket
    result = BuildingConstructionService.construct(
      user: @user,
      system: @system,
      building_type: :mineral_extractor,
      ship: @ship
    )

    assert result.success?
    @user.reload

    # User should have been advanced to emigration phase
    assert @user.emigration?, "User should advance to emigration phase automatically"
    assert @user.has_colonial_ticket?, "User should have Colonial Ticket after building completes proving ground"
  end

  test "constructing building without prior scan does NOT unlock ticket" do
    # No system visit - scan not complete
    # Make sure there are no existing visits
    @user.system_visits.destroy_all

    result = BuildingConstructionService.construct(
      user: @user,
      system: @system,
      building_type: :mineral_extractor,
      ship: @ship
    )

    assert result.success?
    @user.reload

    # Should still be in proving ground
    assert @user.proving_ground?, "User should remain in proving_ground without scan"
    assert_not @user.has_colonial_ticket?
  end

  test "completing scan after building also unlocks ticket" do
    # First build without scan
    @user.system_visits.destroy_all
    result = BuildingConstructionService.construct(
      user: @user,
      system: @system,
      building_type: :mineral_extractor,
      ship: @ship
    )
    @user.reload
    assert @user.proving_ground?, "Should still be proving_ground after building alone"

    # Now complete the scan
    create_system_visit_and_check_ticket

    @user.reload
    assert @user.emigration?, "Should advance to emigration after scan completes requirements"
    assert @user.has_colonial_ticket?
  end

  test "auto-unlock only happens in proving_ground phase" do
    # Set user to cradle phase
    @user.update!(tutorial_phase: :cradle)
    create_system_visit

    result = BuildingConstructionService.construct(
      user: @user,
      system: @system,
      building_type: :mineral_extractor,
      ship: @ship
    )

    assert result.success?
    @user.reload

    # Should remain in cradle (can't advance from cradle via building)
    assert @user.cradle?, "Cradle users should not auto-advance"
  end

  test "auto-unlock provides ticket info in result" do
    create_system_visit

    result = BuildingConstructionService.construct(
      user: @user,
      system: @system,
      building_type: :mineral_extractor,
      ship: @ship
    )

    assert result.success?
    assert result.colonial_ticket_unlocked?, "Result should indicate ticket was unlocked"
    assert result.ticket.present?, "Result should contain ticket info"
    assert result.ticket[:user_id] == @user.id
  end

  test "auto-unlock sends inbox message to user" do
    create_system_visit

    assert_difference -> { @user.messages.count }, 1 do
      BuildingConstructionService.construct(
        user: @user,
        system: @system,
        building_type: :mineral_extractor,
        ship: @ship
      )
    end

    message = @user.messages.last
    assert_match(/colonial ticket/i, message.title)
    assert_match(/emigration/i, message.body)
  end

  private

  def create_system_visit
    SystemVisit.create!(
      user: @user,
      system: @system,
      first_visited_at: Time.current,
      last_visited_at: Time.current,
      visit_count: 1
    )
  end

  def create_system_visit_and_check_ticket
    # This simulates the ScanningService completing a scan
    # which should also trigger the ticket check
    visit = SystemVisit.create!(
      user: @user,
      system: @system,
      first_visited_at: Time.current,
      last_visited_at: Time.current,
      visit_count: 1
    )

    # The scanning service should call the ticket check
    ColonialTicketService.check_and_unlock_if_ready(user: @user)

    visit
  end
end
