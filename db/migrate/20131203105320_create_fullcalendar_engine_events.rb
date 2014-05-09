class CreateFullcalendarEngineEvents < ActiveRecord::Migration
  def change
    create_table :fullcalendar_engine_events do |t|
      t.string :title
      t.datetime :starttime, :endtime
      t.boolean :all_day, :default => false
      t.text :description
      t.date :untildate
      t.string :event_type
      t.string :classroom
      t.integer :event_series_id
      t.timestamps
    end
    add_index :fullcalendar_engine_events, :event_series_id
  end
end
