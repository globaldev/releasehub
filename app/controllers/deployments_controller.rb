class DeploymentsController < ApplicationController

  before_action :setup, :only => [:new, :edit]
  after_action :notify, :only => [:create, :update_status]

  SEARCH_KEYS = {
    "release" => "releases.summary",
    "env" => "environments.name",
    "status" => "statuses.name",
    "notification_list" => "deployments.notification_list",
    "created_at" => "deployments.created_at"
  }

  def new
    @release = Release.new
    @deployment = Deployment.new
    @releases = Release.order(:name => :asc).all
  end

  def create
    @release = Release.find_or_create_by(:name => params["release_name"])
    @release.update(:status_id => Status::OPEN, :summary => params["release_summary"])
    @deployment = Deployment.create(deployment_params.merge(release_id: @release.id))

    project_params.map do |project|
      @deployment.projects.find_or_create_by(
        :branch_id => project[0],
        :sha => project[1],
        :deployment_instruction => project[2],
        :rollback_instruction => project[3])
    end

    flash[:success] = "Thank you, the request has been submitted. It should be deployed shortly."
    redirect_to new_deployment_path
  end

  def edit
    @deployment = Deployment.find(params[:id])
    @release = @deployment.release
    @releases = Release.order(:name => :asc).all
    render :new
  end

  def index
    search_query = search_params
    @deployments = if !search_query.empty?
      Deployment.joins(:status).joins(:release).joins(:environment).where(search_query)
    else
      Deployment
    end.order(:id => :desc).page(params[:page]).per(params[:per_page] || 30)

    @deployment_status = Status.deployment_status if ops?
  end

  def show
    @deployment_status = Status.deployment_status if ops?
    @deployment = Deployment.find(params[:id])
  end

  def update_status
    @deployment = Deployment.find(params["deployment_id"])
    last_operator = @deployment.operation_logs.last.username

    if current_username != last_operator && @deployment.status_id != Status::WAIT_TO_DEPLOY
      result = { error: "The deployment is currently #{@deployment.status.name} by #{last_operator}" }
    else
      @deployment.update(status_id: params["status_id"])
      # record the operations
      OperationLog.create!(username: current_username, status_id: params["status_id"],
        deployment_id: params["deployment_id"])
      result = { name: @deployment.status.name, colour: status_colour(@deployment), ops: current_username }
    end

    respond_with_json result
  end

  private

  def search_params
    if params[:from] && params[:to]
      from = params[:from].to_date.beginning_of_day
      to = params[:to].to_date.end_of_day
      date_range = from..to
    end

    deployment_ids = search_by_ops_and_projects

    {
      "environments.name" => params["environments.name"],
      "deployments.created_at" => date_range,
      :dev => params[:dev],
      "deployments.id" => (deployment_ids unless deployment_ids.empty?)
    }.reject { |key, value| value.blank? }
  end

  def search_by_ops_and_projects
    deployment_ids = []
    deployment_ids.push(OperationLog.where(:username => params[:ops]).pluck(:deployment_id)) if params[:ops].present?
    if params[:project].present?
      deployment_ids.push(
        Project.where(:branch =>
          Repository.find_by(:name => params[:project]).try(:branches)
        ).pluck(:deployment_id)
      )
    end
    deployment_ids
  end

  def setup
    @repositories = Rails.cache.fetch("repos", :expires_in => 1.day) do
      Repository.order(name: :asc).all
    end
    @environments = Rails.cache.fetch("envs", :expires_in => 1.day) { Environment.all }
  end

  def respond_with_json(data, status = 200)
    respond_to do |format|
      format.json { render json: data, status: status }
    end
  end

  def deployment_params
    {
      notification_list: params["deployment"]["notification_list"],
      environment_id: params["deployment"]["environment_id"],
      status_id: Status::WAIT_TO_DEPLOY,
      dev: current_username
    }
  end

  def project_params
    projects = params["deployment"]["projects"]
    projects["branches"].zip(
      projects["shas"],
      projects["deployment_instructions"],
      projects["rollback_instructions"])
  end

  def notify
    project_names = @deployment.projects.map { |project| project.repository.name }.join(", ")
    message = release_message(project_names, @deployment)
    slack_post(channels, message)
  end

  def channels
    list = @deployment.notification_list.split(",")
    list.uniq.reject{ |channel| channel.start_with?("@") }
  end
end
