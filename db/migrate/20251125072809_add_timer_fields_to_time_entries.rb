class AddTimerFieldsToTimeEntries < ActiveRecord::Migration[7.1]
  def change
    add_column :time_entries, :start_time, :datetime
    add_column :time_entries, :end_time, :datetime
  end
end
