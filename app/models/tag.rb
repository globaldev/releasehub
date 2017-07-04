class Tag

  USER_EMAIL_DOMAIN = ENV["RH_USER_EMAIL_DOMAIN"]

  def initialize(project, ops)
    @project = project
    @ops = ops
  end

  def sha
    @project.sha
  end

  def repo
    "#{ReleasesHelper::ORGANISATION}/#{@project.repository.name}"
  end

  def message
    "#{@project.branch.name}\n#{@project.deployment.release.summary}\n"
  end

  def tagger_name
    @ops.name || "Ops".freeze
  end

  def tagger_email
    "#{@ops.slack_username}@#{USER_EMAIL_DOMAIN}"
  end

  def date
    Time.now.utc.iso8601
  end

  def status
    @project.deployment.status.name
  end

  def name
    "#{@project.deployment.environment.name}_#{Date.current}_#{tag_status(status)}"
  end

  def reference
    "tags/#{name}"
  end

  private

  def tag_status(status)
    if status == "deploying"
      status = "deployed"
    end
    status
  end

end
