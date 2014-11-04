module FullcalendarEngine
  class Event < ActiveRecord::Base

    attr_accessor :period, :frequency, :commit_button

    validates :title, :description, :presence => true
    validate :validate_timings
    validates :event_type, :presence => true
    after_create :determine_classroom_and_update_day_care_id

    belongs_to :event_series
    belongs_to :day_care, class_name: "DayCare"

    REPEATS = {
      :no_repeat => "Does Not Repeat",
      :days      => "Daily",
      :weeks     => "Weekly",
      :months    => "Monthly",
      :years     => "Yearly"
    }

    after_create :push_notification 

    def determine_classroom_and_update_day_care_id
      if event_type == 'Schedule'
        self.update_attributes(classroom: "DayCare")
      end
    end

    def validate_timings
      if (starttime >= endtime) and !all_day
        errors[:base] << "Start Time must be less than End Time"
      end
    end

    def update_events(events, event)
      events.each do |e|
        begin 
          old_start_time, old_end_time = e.starttime, e.endtime
          e.attributes = event
          if event_series.period.downcase == 'monthly' or event_series.period.downcase == 'yearly'
            new_start_time = make_date_time(e.starttime, old_start_time) 
            new_end_time   = make_date_time(e.starttime, old_end_time, e.endtime)
          else
            new_start_time = make_date_time(e.starttime, old_end_time)
            new_end_time   = make_date_time(e.endtime, old_end_time)
          end
        rescue
          new_start_time = new_end_time = nil
        end
        if new_start_time and new_end_time
          e.starttime, e.endtime = new_start_time, new_end_time
          e.save
        end
      end

      event_series.attributes = event
      event_series.save
    end

    def push_notification
      Rails.logger.info "------------------ PUSH NO"
      self.day_care.devices.authorized.token_present.android.each do |device|
        data = { 
          "message" => "New Event Created",
          "event_id" => "#{self.id}",
          "type" => "calendar"
        }
        GCM.send_notification(device.token_id, data)
      end
    end

    private

    def make_date_time(original_time, difference_time, event_time = nil)
      DateTime.parse("#{original_time.hour}:#{original_time.min}:#{original_time.sec}, #{event_time.try(:day) || difference_time.day}-#{difference_time.month}-#{difference_time.year}")
    end 
  end
end
