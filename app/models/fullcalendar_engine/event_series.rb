module FullcalendarEngine
  class EventSeries < ActiveRecord::Base
    
    attr_accessor :title, :description, :commit_button, :untildate

    validates :frequency, :period, :starttime, :endtime, :title, :description, :presence => true

    has_many :events, :dependent => :destroy

    after_create :create_events_until_end_time

    def create_events_until_end_time(end_time=untildate)
      old_start_time   = starttime
      old_end_time     = endtime
      frequency_period = recurring_period(period)
      new_start_time, new_end_time = old_start_time, old_end_time
      Rails.logger.info "===============================> old_start_time: #{old_start_time}"
      Rails.logger.info "===============================> old_end_time: #{old_end_time}"
      Rails.logger.info "===============================> frequency_period: #{frequency_period}"
      Rails.logger.info "===============================> new_start_time: #{new_start_time}"
      Rails.logger.info "===============================> new_end_time: #{new_end_time}"
      # Rails.logger.info "===============================> untildate: #{untildate + starttime.strftime("%H")}"
      Rails.logger.info "===============================> starttime; #{starttime.strftime("%H")}"
      Rails.logger.info "===============================> starttime; #{starttime.strftime("%M").to_i.minutes}"
      Rails.logger.info "===============================> starttime; #{starttime.strftime("%S").to_i.seconds}"
      # nil.test!
      end_time = untildate + starttime.strftime("%H").to_i.hours + starttime.strftime("%M").to_i.minutes + starttime.strftime("%S").to_i.seconds
      Rails.logger.info "===============================> end_time; #{end_time}"
      Rails.logger.info "===============================> Day Care Id #{day_care_id}"

      while new_start_time <= (end_time)
        self.events.create( 
                            :title => title, 
                            :description => description, 
                            :all_day => all_day, 
                            :starttime => new_start_time, 
                            :endtime => new_end_time,
                            :event_type => event_type,
                            :classroom => classroom,
                            :untildate => untildate,
                            :day_care_id => day_care_id,
                            :user_id => self.user_id,
                            :all_staff => self.all_staff
                          )
        new_start_time = old_start_time = frequency.send(frequency_period).from_now(old_start_time)
        new_end_time   = old_end_time   = frequency.send(frequency_period).from_now(old_end_time)

        if period.downcase == 'monthly' or period.downcase == 'yearly'
          begin 
            new_start_time = make_date_time(starttime, old_start_time)
            new_end_time   = make_date_time(endtime, old_end_time)
          rescue
            new_start_time = new_end_time = nil
          end
        end
        Rails.logger.info "==============================> #{new_start_time}"
        Rails.logger.info "==============================> #{new_start_time <= (end_time)}"
      end
    end

    def recurring_period(period)
      Event::REPEATS.key(period.titleize).to_s.downcase
    end

    private 

      def make_date_time(original_time, difference_time)
        DateTime.parse("#{original_time.hour}:#{original_time.min}:#{original_time.sec}, #{original_time.day}-#{difference_time.month}-#{difference_time.year}")
      end
  end
end
