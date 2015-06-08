require_dependency 'fullcalendar_engine/application_controller'

module FullcalendarEngine
  class EventsController < ApplicationController
    include ApplicationHelper

    layout FullcalendarEngine::Configuration['layout'] || 'application'

    before_filter :load_event, only: [:edit, :update, :destroy, :move, :resize]
    before_filter :determine_event_type, only: :create
    before_filter :authenticate_user!

    authorize_actions_for :calendar_class, :actions => { :index => :read, new: 'create', :create => 'create', :move => 'create', :resize => 'create', :edit => 'create', update: 'create', destroy: 'create', get_events: 'read' }


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
      render json: events.to_json
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

    private

    def load_event
      @event = Event.where(:id => params[:id]).first
      unless @event
        render json: { message: "Event Not Found.."}, status: 404 and return
      end
    end

    def event_params
      params.require(:event).permit('title', 'description', 'starttime', 'endtime', 'all_day', 'period', 'frequency', 'commit_button', 'untildate', 'event_type', 'classroom')
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
