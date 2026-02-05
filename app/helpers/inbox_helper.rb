module InboxHelper
  # Returns count of unread messages for a user
  def unread_count(user)
    user.messages.unread.count
  end

  # Returns badge HTML for unread count, or nil if count is 0
  def unread_badge(user)
    count = unread_count(user)
    return nil if count.zero?

    content_tag(:span, count, class: "unread-badge ml-2 px-2 py-0.5 text-xs bg-orange-500 text-white rounded-full",
      id: "inbox-unread-badge",
      data: {
        controller: "unread-counter",
        unread_counter_count_value: count
      })
  end
end
