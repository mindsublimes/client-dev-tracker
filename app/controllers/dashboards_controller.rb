class DashboardsController < ApplicationController
  def show
    authorize AgendaItem, :dashboard?

    scope = policy_scope(AgendaItem.includes(:client, :assignee))
    @status_counts = AgendaItem.statuses.keys.index_with { |status| scope.where(status:).count }
    @work_stream_counts = AgendaItem.work_streams.keys.index_with { |stream| scope.where(work_stream: stream).count }

    @top_agenda_items = scope.pending.ranked.limit(6)
    @overdue_agenda_items = scope.pending.where('due_on < ?', Date.current).order(due_on: :asc).limit(5)
    @upcoming_agenda_items = scope.pending.where(due_on: Date.current..(Date.current + 14.days)).order(:due_on).limit(5)

    client_scope = policy_scope(Client.includes(:agenda_items))
    @client_snapshots = client_scope.map do |client|
      open_items = client.agenda_items.pending
      recent_velocity = client.agenda_items.where(status: :completed).where('updated_at > ?', 14.days.ago).count
      {
        client:,
        open_items: open_items.count,
        urgent_items: open_items.where(priority_level: :urgent).count,
        overdue_items: open_items.where('due_on < ?', Date.current).count,
        velocity: recent_velocity
      }
    end
  end
end
