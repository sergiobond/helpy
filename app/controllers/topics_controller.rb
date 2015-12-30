class TopicsController < ApplicationController

  before_filter :authenticate_user!, :except => ['show','index','tag','make_private', 'new', 'create', 'up_vote']
  before_filter :instantiate_tracker

  # GET /topics
  # GET /topics.xml
  def index
    @forum = Forum.ispublic.where(id: params[:forum_id]).first
    if @forum
      if @forum.allow_topic_voting == true
        @topics = @forum.topics.ispublic.by_popularity.page params[:page]
      else
        @topics = @forum.topics.ispublic.chronologic.page params[:page]
      end

      #@feed_link = "<link rel='alternate' type='application/rss+xml' title='RSS' href='#{forum_topics_url}.rss' />"

      @page_title = @forum.name.titleize
      @title_tag = "#{Settings.site_name}: #{@page_title}"
      add_breadcrumb t(:community, default: "Community"), forums_path
      add_breadcrumb @forum.name.titleize
    end

    respond_to do |format|
      if @forum
        format.html # index.rhtml
        format.xml  { render :xml => @topics.to_xml }
        format.rss
      else
        format.html { redirect_to root_path }
      end
    end
  end

  def tickets

    @topics = current_user.topics.isprivate.undeleted.chronologic.page params[:page]
    @page_title = t(:tickets, default: 'Tickets')
    add_breadcrumb @page_title

    @title_tag = "#{Settings.site_name}: #{@page_title}"

    #@feed_link = "<link rel='alternate' type='application/rss+xml' title='RSS' href='#{forum_topics_url}.rss' />"

    respond_to do |format|
      format.html # index.rhtml
      format.xml  { render :xml => @topics.to_xml }
      format.rss
    end
  end


  def ticket

    @topic = current_user.topics.undeleted.where(id: params[:id]).first
    if @topic
      @posts = @topic.posts.ispublic.chronologic.active.all

      @page_title = "##{@topic.id} #{@topic.name.titleize}"
      add_breadcrumb t(:tickets, default: 'Tickets'), tickets_path
      add_breadcrumb @page_title

      @title_tag = "#{Settings.site_name}: #{@page_title}"
    end

    respond_to do |format|
      if @topic
        format.html # index.rhtml
        format.xml  { render :xml => @topics.to_xml }
        format.rss
      else
        format.html { redirect_to root_path}
      end
    end


  end


  # GET /topics/1
  # GET /topics/1.xml
  def show

  end

  # GET /topics/new
  def new

    @page_title = t(:start_discussion, default: "Start a New Discussion")
    add_breadcrumb @page_title
    @title_tag = "#{Settings.site_name}: #{@page_title}"

    @forums = Forum.ispublic.all
    @topic = Topic.new
    @user = @topic.build_user unless user_signed_in?

    render layout: 'clean'

  end

  # GET /topics/1;edit
  def edit
    @topic = Topic.find(params[:id])
  end

  # POST /topics
  # POST /topics.xml
  def create

    @page_title = t(:start_discussion, default: "Start a New Discussion")
    add_breadcrumb @page_title
    @title_tag = "#{Settings.site_name}: #{@page_title}"

    params[:id].nil? ? @forum = Forum.find(params[:topic][:forum_id]) : @forum = Forum.find(params[:id])
    logger.info(@forum.name)

    @topic = @forum.topics.new(
      name: params[:topic][:name],
      private: params[:topic][:private],
      doc_id: params[:topic][:doc_id] )

    unless user_signed_in?

      # User is not signed in, lets see if we can recognize the email address
      @user = User.where(email: params[:topic][:user][:email]).first

      if @user
        logger.info("User found")
        @topic.user_id = @user.id

      else #User not found, lets build it
        @user = @topic.build_user
        @user.name = params[:topic][:user][:name]
        @user.login = params[:topic][:user][:email].split("@")[0]
        @user.email = params[:topic][:user][:email]
        @user.password = User.create_password
        built_user = true
      end

    else
      @user = current_user
      @topic.user_id = @user.id

    end

    respond_to do |format|

      if @user.save && @topic.save

        @post = @topic.posts.create(
          :body => params[:post][:body],
          :user_id => @user.id,
          :kind => 'first',
          :screenshots => params[:topic][:screenshots])

        if built_user == true && !user_signed_in?
          UserMailer.new_user(@user).deliver_now
          sign_in(:user, @user)
        end

        # track event in GA
        @tracker.event(category: 'Request', action: 'Post', label: 'New Topic')
        @tracker.event(category: 'Agent: Unassigned', action: 'New', label: @topic.to_param)

        format.html {
          if @topic.private?
            redirect_to ticket_path(@topic)
          else
            redirect_to topic_posts_path(@topic)
          end
          }
      else
        format.html { render action: 'new' }
      end
    end

  end

  # PUT /topics/1
  # PUT /topics/1.xml
  def update
    @topic = Topic.find(params[:id])
    @topic.tag_list = params[:tags]
    respond_to do |format|
      if @topic.update_attributes(params[:topic])
        #flash[:notice] = 'Topic was successfully updated.'
        format.html { redirect_to topic_posts_path(@topic) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @topic.errors.to_xml }
      end
    end
  end

  # DELETE /topics/1
  # DELETE /topics/1.xml
  def destroy
    @topic = Topic.find(params[:id])
    @topic.posts.each { |post| post.destroy }
    @topic.destroy

    respond_to do |format|
      format.html { redirect_to forum_topics_path(@topic.forum) }
      format.xml  { head :ok }
    end
  end

  def up_vote

    if user_signed_in?
      @topic = Topic.find(params[:id])
      @topic.votes.create(user_id: current_user.id)
      @topic.touch
      @topic.reload
    end
    respond_to do |format|
      format.js
    end

  end

  def tag
    @topics = Topic.ispublic.tag_counts_on(:tags)
  end
end
