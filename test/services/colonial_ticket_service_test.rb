# frozen_string_literal: true

require "test_helper"

class ColonialTicketServiceTest < ActiveSupport::TestCase
  # The Colonial Ticket is unlocked when Phase 2 (Proving Ground) is complete
  # It grants passage to Phase 3 (Emigration) - the one-time drop

  setup do
    @user = User.create!(
      email: "emigrant@example.com",
      name: "Emigrant Test",
      tutorial_phase: :proving_ground,
      credits: 5000
    )
    # Discover a system
    @system = System.discover_at(x: 1, y: 0, z: 0, user: @user)
  end

  # Completion requirements
  test "proving_ground_complete? returns false without any progress" do
    assert_not ColonialTicketService.proving_ground_complete?(user: @user)
  end

  test "proving_ground_complete? requires at least one scan" do
    # Create a building but no scan
    create_building_for_user

    assert_not ColonialTicketService.proving_ground_complete?(user: @user),
      "Should not be complete without scan"
  end

  test "proving_ground_complete? requires at least one building" do
    # Create a scan but no building
    create_scan_record_for_user

    assert_not ColonialTicketService.proving_ground_complete?(user: @user),
      "Should not be complete without building"
  end

  test "proving_ground_complete? returns true when both scan and building exist" do
    create_scan_record_for_user
    create_building_for_user

    assert ColonialTicketService.proving_ground_complete?(user: @user)
  end

  # Ticket unlock
  test "unlock_colonial_ticket fails if proving ground not complete" do
    result = ColonialTicketService.unlock_colonial_ticket(user: @user)

    assert_not result.success?
    assert_match(/requirements not met/i, result.error)
  end

  test "unlock_colonial_ticket advances user to emigration phase" do
    complete_proving_ground

    result = ColonialTicketService.unlock_colonial_ticket(user: @user)

    assert result.success?
    @user.reload
    assert @user.emigration?
  end

  test "unlock_colonial_ticket returns ticket information" do
    complete_proving_ground

    result = ColonialTicketService.unlock_colonial_ticket(user: @user)

    assert result.success?
    assert result.ticket.present?
    assert result.ticket[:issued_at].present?
    assert result.ticket[:user_id] == @user.id
  end

  test "unlock_colonial_ticket only works in proving_ground phase" do
    @user.update!(tutorial_phase: :cradle)

    result = ColonialTicketService.unlock_colonial_ticket(user: @user)

    assert_not result.success?
    assert_match(/must be in proving ground/i, result.error)
  end

  test "unlock_colonial_ticket cannot be used twice" do
    complete_proving_ground
    ColonialTicketService.unlock_colonial_ticket(user: @user)
    @user.reload

    result = ColonialTicketService.unlock_colonial_ticket(user: @user)

    assert_not result.success?
    assert_match(/must be in proving ground/i, result.error)
  end

  # Progress tracking
  test "proving_ground_progress returns completion status" do
    progress = ColonialTicketService.proving_ground_progress(user: @user)

    assert progress.key?(:scan_complete)
    assert progress.key?(:building_complete)
    assert progress.key?(:overall_complete)
    assert_not progress[:overall_complete]
  end

  test "proving_ground_progress updates when objectives completed" do
    progress_before = ColonialTicketService.proving_ground_progress(user: @user)
    assert_not progress_before[:scan_complete]

    create_scan_record_for_user

    progress_after = ColonialTicketService.proving_ground_progress(user: @user)
    assert progress_after[:scan_complete]
  end

  # User model integration
  test "User#has_colonial_ticket? returns false before unlock" do
    assert_not @user.has_colonial_ticket?
  end

  test "User#has_colonial_ticket? returns true after unlock" do
    complete_proving_ground
    ColonialTicketService.unlock_colonial_ticket(user: @user)
    @user.reload

    assert @user.has_colonial_ticket?
  end

  test "User#can_emigrate? requires colonial ticket" do
    assert_not @user.can_emigrate?

    complete_proving_ground
    ColonialTicketService.unlock_colonial_ticket(user: @user)
    @user.reload

    assert @user.can_emigrate?
  end

  private

  def create_scan_record_for_user
    # Create a system visit to represent successful scan
    SystemVisit.create!(
      user: @user,
      system: @system,
      first_visited_at: Time.current,
      last_visited_at: Time.current,
      visit_count: 1
    )
  end

  def create_building_for_user
    Building.create!(
      user: @user,
      system: @system,
      name: "Test Extractor",
      race: "krog",
      function: "defense",
      tier: 1,
      status: "active"
    )
  end

  def complete_proving_ground
    create_scan_record_for_user
    create_building_for_user
  end
end
