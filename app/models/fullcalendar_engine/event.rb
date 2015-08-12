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
    before_save :revert_class

    def revert_class
       
            day_care_class = DayCare.find_by_id(self.day_care_id).daycare_class.first
        
        	case self.classroom
                when day_care_class.one_year then
		       self.classroom = "Infant"
	        when day_care_class.one_to_two_years then
                        self.classroom = "Toddlers"
         	when day_care_class.two_to_three_years then
                        self.classroom = "Early Learners"
	        when day_care_class.three_to_four_years then
                        self.classroom = "Pre School"
	        when day_care_class.four_to_five_years then
                        self.classroom = "Pre-kindergarten"
             else
                 Rails.logger.info "No classroom mentioned"                
             end
          
    end

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
        Rails.logger.info "-------- PUSH OUTSIDE DEVICE LOOP "
      self.day_care.parent_devices.authorized.token_present.android.each do |device|
        Rails.logger.info "-------------#{device.parent.children.classrooms}"
        if ["DayCare", "All Classroom"].include?(self.classroom) || device.parent.children.classrooms.include?(self.classroom)
          Rails.logger.info "------------------ PUSH IF CONDITION TRUE"
          data = { 
            "message" => "New Event Created",
            "event_id" => "#{self.id}",
            "type" => "calendar"
          }
          GCM.send_notification(device.token_id, data,:identity => :key1)
        end
      end
    end

    private

    def make_date_time(original_time, difference_time, event_time = nil)
      DateTime.parse("#{original_time.hour}:#{original_time.min}:#{original_time.sec}, #{event_time.try(:day) || difference_time.day}-#{difference_time.month}-#{difference_time.year}")
    end 
  end
end
