class ConversationsController < ApplicationController
  before_filter :signed_in_user
  before_filter :get_actor, :get_mailbox, :get_box
  before_filter :check_current_subject_in_conversation, :only => [:show, :show_small, :update, :update_small, :destroy]
  before_action :get_fleets,     only: [:index, :show]
  
  def index
    #if params[:voyages_port]
    #  @conversations = @mailbox.inbox.where("conversation_id IN (#{labeled_by_vp})", voyages_port_id: params[:voyages_port]).page(params[:page])
    if @box.empty?
      @contacts = contacts
      if params[:conversation_id]
        @conversation = Conversation.find params[:conversation_id]
        @contact = contact_by_conversation params[:conversation_id]
        @conversations = Conversation.where("id IN (#{conversations_by_contact @contact})").order(created_at: :desc)
      elsif params[:receiver_id] and params[:receiver_type]
        @contact = contact_by_receiver params[:receiver_id], params[:receiver_type]
        @conversations = Conversation.where("id IN (#{conversations_by_contact @contact})").order(created_at: :desc)
        @conversation = @conversations.first
      else
        @contact = @contacts.first
        @conversations = Conversation.where("id IN (#{conversations_by_contact @contact})").order(created_at: :desc)
        @conversation = @conversations.first
      end
        @receipts = @mailbox.receipts_for(@conversation).not_trash.reverse
    elsif @box.eql? "inbox"
      @conversations = @mailbox.inbox.page(params[:page])#.per(9)
    elsif @box.eql? "sentbox"
      @conversations = @mailbox.sentbox.page(params[:page])#.per(9)
    else
      @conversations = @mailbox.trash.page(params[:page])#.per(9)
    end
    respond_to do |format|
      format.html { render @conversations if request.xhr? }
    end
  end

  def show
    redirect_to :action => 'index', :conversation_id => params[:id]
    #if @box.eql? 'trash'
    #  @receipts = @mailbox.receipts_for(@conversation).trash
    #else
    #  @receipts = @mailbox.receipts_for(@conversation).not_trash
    #end
    #render :action => :show
    #@receipts.mark_as_read
    #Reader.create(user_id: current_user.id, conversation_id: @conversation.id)
    #@receipts.each do |receipt|
    #  if (receipt.mailbox_type == "inbox") and ((receipt.receiver_type == "Agent" and current_user.agent_id == receipt.receiver_id) or (receipt.receiver_type == "ShippingCompany" and current_user.shipping_company_id == receipt.receiver_id))
    #    Reader.create(user_id: current_user.id, notification_id: receipt.notification.id)
    #  end
    #end
  end

  def update
    if params[:untrash].present?
    @conversation.untrash(@actor)
    end

    if params[:reply_all].present?
      last_receipt = @mailbox.receipts_for(@conversation).last
      @receipt = @actor.reply_to_all(last_receipt, params[:body])
      Sender.create(notification_id: @receipt.notification.id, user_id: current_user.id)
    end

    if @box.eql? 'trash'
      @receipts = @mailbox.receipts_for(@conversation).trash
    else
      @receipts = @mailbox.receipts_for(@conversation).not_trash
    end
    redirect_to :action => :show
    @receipts.mark_as_read
  end

  def destroy

    @conversation.move_to_trash(@actor)

    respond_to do |format|
      format.html {
        if params[:location].present? and params[:location] == 'conversation'
          redirect_to conversations_path(:box => :trash)
        else
          redirect_to conversations_path(:box => @box,:page => params[:page])
        end
      }
      format.js {
        if params[:location].present? and params[:location] == 'conversation'
          render :js => "window.location = '#{conversations_path(:box => @box,:page => params[:page])}';"
        else
          render 'conversations/destroy'
        end
      }
    end
  end

  def show_small
    if @box.eql? 'trash'
      @receipts = @mailbox.receipts_for(@conversation).trash
    else
      @receipts = @mailbox.receipts_for(@conversation).not_trash
    end
    render :layout => false
    @receipts.mark_as_read
    Reader.create(user_id: current_user.id, conversation_id: @conversation.id)
    @receipts.each do |receipt|
      if (receipt.mailbox_type == "inbox") and ((receipt.receiver_type == "Agent" and current_user.agent_id == receipt.receiver_id) or (receipt.receiver_type == "ShippingCompany" and current_user.shipping_company_id == receipt.receiver_id))
        Reader.create(user_id: current_user.id, notification_id: receipt.notification.id)
      end
    end
  end

  def update_small
    if params[:untrash].present?
    @conversation.untrash(@actor)
    end
    if params[:reply_all].present?
      last_receipt = @mailbox.receipts_for(@conversation).last
      @receipt = @actor.reply_to_all(last_receipt, params[:body])
      Sender.create(notification_id: @receipt.notification.id, user_id: current_user.id)
    end
    if @box.eql? 'trash'
      @receipts = @mailbox.receipts_for(@conversation).trash
    else
      @receipts = @mailbox.receipts_for(@conversation).not_trash
    end
    @receipts.mark_as_read
  end

  def refresh_latest
    respond_to do |format|
      format.js
    end
  end


  def refresh_feed
    respond_to do |format|
      format.js
    end
  end
  
  
  def search
    @term = params[:term]
    if sce?
        @fleets = current_user.shipping_company.fleets
        @ships = current_user.shipping_company.ships
        @voyages = current_user.shipping_company.voyages
      elsif ase?
        @fleets = Fleet.none
        @voyages_ports = current_user.agent.voyages_ports
      end
      @mailbox_type = []
      if params[:inbox]=='1'
        @mailbox_type.push "inbox"
      end
      if params[:sentbox]=='1'
        @mailbox_type.push "sentbox"
      end
      #if params[:notifications]=='1'
      #  @mailbox_type.push ""
      #end
      if params[:end]
        endtime = params[:end]
      else
        endtime = Time.now
      end 
      unless @mailbox_type.empty?
        if params[:start]
          @results = Receipt.search @term, page: params[:inbox_page], per_page: 10, load: false, fields: ["subject^10", "body^5"], partial: true, where: { mailbox_type: @mailbox_type , receiver_id: get_company_id, receiver_type: get_company_type, :created_at=>{:lte=> endtime}, :created_at=>{:gte=>params[:start]} }
        else
          @results = Receipt.search @term, page: params[:inbox_page], per_page: 10, load: false, fields: ["subject^10", "body^5"], partial: true, where: { mailbox_type: @mailbox_type , receiver_id: get_company_id, receiver_type: get_company_type, :created_at=>{:lte=> endtime} }
        end
      else
        @results = Receipt.none
      end
  end

  private

  def get_box
    if params[:box].blank? or !["inbox","sentbox","trash"].include?params[:box]
      params[:box] = ''
    end
    @box = params[:box]
  end

  def check_current_subject_in_conversation
    @conversation = Conversation.find_by_id(params[:id])
    if @conversation.nil? or !@conversation.is_participant?(@actor)
      redirect_to conversations_path(:box => @box)
    return
    end
  end
  
  private

    def labeled_by_vp
      clause = "SELECT conversation_id FROM labels WHERE voyages_port_id = :voyages_port_id"
    end
    
    def contacts
      ActiveRecord::Base.connection.execute("SELECT receiver_id, receiver_type, max(created_at) as max FROM receipts WHERE (receiver_id != '#{get_company_id}' or receiver_type != '#{get_company_type}') and notification_id IN (SELECT notification_id FROM receipts WHERE receiver_id = '#{get_company_id}' and receiver_type = '#{get_company_type}') group by receiver_id, receiver_type order by max(created_at) desc")
    end
    
    def contact_by_conversation(conversation_id)
      ActiveRecord::Base.connection.execute("SELECT receiver_id, receiver_type, max(r.created_at) as max FROM receipts r, notifications n WHERE (receiver_id != '#{get_company_id}' or receiver_type != '#{get_company_type}') and r.notification_id = n.id and conversation_id = '#{conversation_id}' group by receiver_id, receiver_type").first
    end
    
    def contact_by_receiver(receiver_id, receiver_type)
      ActiveRecord::Base.connection.execute("SELECT r1.receiver_id, r1.receiver_type, max(r1.created_at) as max FROM receipts r1, receipts r2 WHERE r1.notification_id = r2.notification_id and r1.receiver_id = '#{receiver_id}' and r1.receiver_type = '#{receiver_type}' and r2.receiver_id = '#{get_company_id}' and r2.receiver_type = '#{get_company_type}' group by r1.receiver_id, r1.receiver_type").first
    end

    def conversations_by_contact(contact)
      "SELECT distinct n.conversation_id FROM receipts r, notifications n WHERE r.receiver_id = '#{contact["receiver_id"]}' and r.receiver_type = '#{contact["receiver_type"]}' and r.notification_id = n.id and r.notification_id IN (SELECT notification_id FROM receipts WHERE receiver_id = '#{get_company_id}' and receiver_type = '#{get_company_type}')"
    end

end