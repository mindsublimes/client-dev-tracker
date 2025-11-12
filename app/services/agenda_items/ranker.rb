module AgendaItems
  class Ranker
    PRIORITY_WEIGHTS = {
      'low' => 10,
      'normal' => 25,
      'high' => 45,
      'urgent' => 70
    }.freeze

    STATUS_WEIGHTS = {
      'blocked' => 25,
      'in_review' => 5,
      'completed' => -150,
      'archived' => -200
    }.freeze

    def initialize(agenda_item)
      @agenda_item = agenda_item
    end

    def apply
      breakdown = {
        priority: priority_weight,
        due_date: due_date_weight,
        complexity: complexity_weight,
        status: status_weight,
        inactivity: inactivity_weight
      }

      @agenda_item.rank_breakdown = breakdown
      @agenda_item.rank_score = breakdown.values.sum
      @agenda_item.last_ranked_at = Time.current
    end

    private

    def priority_weight
      PRIORITY_WEIGHTS.fetch(@agenda_item.priority_level, 0)
    end

    def due_date_weight
      return 0 if @agenda_item.due_on.blank?

      days_remaining = (@agenda_item.due_on - Date.current).to_i

      case days_remaining
      when ..-1
        80
      when 0
        65
      when 1..3
        55
      when 4..7
        40
      when 8..14
        25
      else
        10
      end
    end

    def complexity_weight
      value = @agenda_item.complexity.to_i
      value = 3 if value.zero?
      (6 - value) * 6
    end

    def status_weight
      STATUS_WEIGHTS.fetch(@agenda_item.status, 0)
    end

    def inactivity_weight
      last_touch = [@agenda_item.updated_at, last_message_at].compact.max || Time.current
      days_since_activity = ((Time.current - last_touch) / 1.day).floor
      [[days_since_activity * 4, 0].max, 30].min
    end

    def last_message_at
      @agenda_item.agenda_messages.maximum(:created_at)
    end
  end
end
