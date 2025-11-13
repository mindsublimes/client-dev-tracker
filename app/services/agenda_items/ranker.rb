module AgendaItems
  class Ranker
    PRIORITY_WEIGHTS = {
      'low'    => 5,
      'normal' => 10,
      'high'   => 15,
      'urgent' => 20
    }.freeze

    STATUS_WEIGHTS = {
      'blocked'   => 15,
      'in_review' => 5,
      'completed' => -20,
      'archived'  => -20
    }.freeze

    def initialize(agenda_item)
      @agenda_item = agenda_item
    end

    def apply
      if @agenda_item.status == 'cancelled'
        breakdown = {
          priority:   0,
          due_date:   0,
          complexity: 0,
          status:     0,
          inactivity: 0,
          raw_score:  0
        }

        @agenda_item.rank_breakdown = breakdown
        @agenda_item.rank_score     = 0
        @agenda_item.last_ranked_at = Time.current
        return
      end

      breakdown = {
        priority:   priority_weight,
        due_date:   due_date_weight,
        complexity: complexity_weight,
        status:     status_weight,
        inactivity: inactivity_weight
      }

      raw_score   = breakdown.values.sum
      final_score = clamp_score(raw_score)

      @agenda_item.rank_breakdown = breakdown.merge(raw_score: raw_score)
      @agenda_item.rank_score     = final_score
      @agenda_item.last_ranked_at = Time.current
    end

    private

    def clamp_score(score)
      return 0   if score < 0
      return 100 if score > 100

      score
    end

    def priority_weight
      PRIORITY_WEIGHTS.fetch(@agenda_item.priority_level, 0)
    end

    def due_date_weight
      return 0 if @agenda_item.due_on.blank?

      days_remaining = (@agenda_item.due_on - Date.current).to_i

      case days_remaining
      when ..-1 then 30
      when 0    then 25
      when 1..3 then 20
      when 4..7 then 15
      when 8..14 then 10
      else 5
      end
    end

    def complexity_weight
      value = @agenda_item.complexity.to_i
      value = 3 if value <= 0
      value = 5 if value > 5

      case value
      when 1 then 15
      when 2 then 12
      when 3 then 9
      when 4 then 6
      when 5 then 3
      else 9
      end
    end

    def status_weight
      STATUS_WEIGHTS.fetch(@agenda_item.status, 0)
    end

    def inactivity_weight
      last_touch = [@agenda_item.updated_at, last_message_at].compact.max || Time.current
      days_since_activity = ((Time.current - last_touch) / 1.day).floor
      days = [days_since_activity, 0].max
      [days, 15].min
    end

    def last_message_at
      @agenda_item.agenda_messages.maximum(:created_at)
    end
  end
end
