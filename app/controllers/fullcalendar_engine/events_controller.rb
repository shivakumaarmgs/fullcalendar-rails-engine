require_dependency 'fullcalendar_engine/application_controller'

module FullcalendarEngine
  class EventsController < ApplicationController

    layout FullcalendarEngine::Configuration['layout'] || 'application'

    before_filter :load_event, only: [:edit, :update, :destroy, :move, :resize]
    before_filter :determine_event_type, only: :create
    before_filter :authenticate_user!
    before_filter :check_current_user_staff, only:[:staff_calendar]

    authorize_actions_for :calendar_class, :actions => { :index => :read, new: 'create', :create => 'create', :move => 'create', :resize => 'create', :edit => 'create', update: 'create', destroy: 'create', get_events: 'read',get_staff_events: 'read' , :staff_calendar => :read,calendar_month_print: 'read',calendar_week_print: 'read',calendar_day_print: 'read' }


    def calendar_class
      [ApplicationAuthorizer, {model: "calendar"}]
    end

    def create
      if @event.save
        render nothing: true
      else
        render text: @event.errors.full_messages.to_sentence, status: 422
      end
    end

    def new
      Rails.logger.info "----------- #{Permission.first}"
      respond_to do |format|
        format.js
      end
    end

    def get_events
      @events = current_day_care.events.where('starttime  >= :start_time and 
                            endtime     <= :end_time',
                            start_time: Time.at(params['start'].to_i).to_formatted_s(:db),
                            end_time:   Time.at(params['end'].to_i).to_formatted_s(:db),
                                             )
      events = []
      @events.each do |event|
        if event.user_id.nil?
          events << { id: event.id,
                      title: event.title,
                      description: event.description || '', 
                      start: event.starttime.iso8601,
                      end: event.endtime.iso8601,
                      allDay: event.all_day,
                      event_type: event.event_type,
                      classroom: event.classroom,
                      color: set_event_color(event.event_type),
                      recurring: (event.event_series_id) ? true : false }
        end
      end
      render json: events.to_json
    end

    def get_staff_events
      @events = current_day_care.events.where('starttime  >= :start_time and 
                            endtime     <= :end_time',
                            start_time: Time.at(params['start'].to_i).to_formatted_s(:db),
                            end_time:   Time.at(params['end'].to_i).to_formatted_s(:db),
                                             )
      staff_events = []
      @events.each do |event|
       if event.user_id == current_user.id || event.all_staff == true
           staff_events << { id: event.id,
                      title: event.title,
                      description: event.description || '', 
                      start: event.starttime.iso8601,
                      end: event.endtime.iso8601,
                      allDay: event.all_day,
                      event_type: event.event_type,
                      classroom: event.classroom,
                      color: set_event_color(event.event_type),
                      recurring: (event.event_series_id) ? true : false }
        end
      end
      render json: staff_events.to_json
    end

    def move
      if @event
        @event.starttime = make_time_from_minute_and_day_delta(@event.starttime)
        @event.endtime   = make_time_from_minute_and_day_delta(@event.endtime)
        @event.all_day   = params[:all_day]
        @event.save
      end
      render nothing: true
    end

    def resize
      if @event
        @event.endtime = make_time_from_minute_and_day_delta(@event.endtime)
        @event.save
      end    
      render nothing: true
    end

    def edit
      render json: { form: render_to_string(partial: 'edit_form') } 
    end

    def update
      case params[:event][:commit_button]
      when 'Update All Occurrence'
        @events = @event.event_series.events
        @event.update_events(@events, event_params)
      when 'Update All Following Occurrence'
        @events = @event.event_series.events.where('starttime > :start_time', 
                                                   start_time: @event.starttime.to_formatted_s(:db)).to_a
        @event.update_events(@events, event_params)
      else
        @event.attributes = event_params
        @event.save
      end
      render nothing: true
    end

    def destroy
      case params[:delete_all]
      when 'true'
        @event.event_series.destroy
      when 'future'
        @events = @event.event_series.events.where('starttime > :start_time',
                                                   start_time: @event.starttime.to_formatted_s(:db)).to_a
        @event.event_series.events.delete(@events)
      else
        @event.destroy
      end
      render nothing: true
    end
    def staff_calendar
      
    end

    def calendar_month_print 
      if cookies[:calendar_month]
        get_month = Date.parse(cookies[:calendar_month])
        start_date = get_month.to_s
        end_date = get_month.end_of_month.to_s
        @monthly_events = Event.where("starttime >= ? and endtime <= ? and day_care_id =? and user_id IS ?", start_date, end_date,current_day_care.id,nil)
      end
      respond_to do |format|
        format.pdf do
          pdf = PDF::CalendarEventPDF.new
          pdf.calendar_monthly(@monthly_events,current_day_care,cookies[:calendar_month]) if cookies[:calendar_month]
          send_data pdf.render, filename: "monthly_events.pdf",
            type: "application/pdf",
            disposition: "inline"
        end
      end
    end

    def calendar_week_print  
      if cookies[:calendar_week]
        week_start_and_end_date = cookies[:calendar_week]
        splited_dates = week_start_and_end_date.split
        if splited_dates[3].to_i == 0
          week_start_date = splited_dates[0]+" "+splited_dates[1]+" "+splited_dates[5]
          start_date = Date.parse(week_start_date).to_s
          week_end_date = splited_dates[3]+" "+splited_dates[4]+" "+splited_dates[5]
          end_date = Date.parse(week_end_date).to_s
        else
          week_start_date = splited_dates[0]+" "+splited_dates[1]+" "+splited_dates[4]
          start_date = Date.parse(week_start_date).to_s
          week_end_date = splited_dates[0]+" "+splited_dates[3]+" "+splited_dates[4]
          end_date = Date.parse(week_end_date).to_s
        end
        @weekly_events = Event.where("starttime >= ? and endtime <= ? and day_care_id =? and user_id IS ?", start_date, end_date,current_day_care.id,nil)
      end
      respond_to do |format|
        format.pdf do
          pdf = PDF::CalendarEventPDF.new
          pdf.calendar_weekly(@weekly_events,current_day_care,cookies[:calendar_week])
          send_data pdf.render, filename: "weekly_events.pdf",
            type: "application/pdf",
            disposition: "inline"
        end
      end
    end

    def calendar_day_print
      if cookies[:calendar_day]
        date = Date.parse(cookies[:calendar_day]).to_s
        @daily_events = Event.where("date(starttime) in (?) and day_care_id =? and user_id IS?", date,current_day_care.id,nil)
      end
      respond_to do |format|
          format.pdf do
            pdf = PDF::CalendarEventPDF.new
            pdf.calendar_daily(@daily_events,current_day_care,cookies[:calendar_day])
            send_data pdf.render, filename: "daily_events.pdf",
              type: "application/pdf",
              disposition: "inline"
          end
        end
    end

    private

    def load_event
      @event = Event.where(:id => params[:id]).first
      unless @event
        render json: { message: "Event Not Found.."}, status: 404 and return
      end
    end

    def check_current_user_staff
      if current_user.role == "day_care"
        redirect_to 'events#index'
      end
    end

    def event_params
      params.require(:event).permit('title', 'description', 'starttime', 'endtime', 'all_day', 'period', 'frequency', 'commit_button', 'untildate', 'event_type', 'classroom', 'user_id', 'all_staff')
    end

    def determine_event_type
      if params[:event][:period] == "Does Not Repeat"
        @event = Event.new(event_params)
        @event.day_care_id = current_day_care.id
      else
        @event = EventSeries.new(event_params)
        @event.day_care_id = current_day_care.id
      end
    end

    def set_event_color(event_type)
      if event_type == "Schedule"
        'red'
      elsif event_type == "Activity"
        'green'
      else
        'blue'
      end
    end

    def make_time_from_minute_and_day_delta(event_time)
      params[:minute_delta].to_i.minutes.from_now((params[:day_delta].to_i).days.from_now(event_time))
    end

    def current_day_care
      current_day_care = current_user.day_care
      if current_day_care.nil?
        if current_user.has_role? "director"
          current_day_care = current_user.director.day_care
        elsif current_user.has_role? "assistant_director"
          current_day_care = current_user.assistant_director.day_care
        else
          current_day_care = current_user.teacher.day_care
        end
      end
      current_day_care
    end

  end
end
