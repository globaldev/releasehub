class Deployment < ActiveRecord::Base
  validates :release_id, presence: true
  validates :status_id, presence: true
  validates :environment_id, presence: true
  validates :dev, presence: true

  belongs_to :release
  belongs_to :status
  belongs_to :environment
  has_many :projects
  has_many :operation_logs

  attr_reader :api_client

  NOTIFY_STATUS = Set[Status::DEPLOYED, Status::ROLLBACK]
  USER_EMAIL_DOMAIN = ENV["RH_USER_EMAIL_DOMAIN"]

  def repo_names
    projects.map { |project| project.repository.name }.join(",")
  end

  def notify_people?
    NOTIFY_STATUS.include?(status_id)
  end

  def last_operator
    operation_logs.last
  end

  def attach_deployment_tags(ops, api_client)
    @api_client ||= api_client

    if environment.production?

    else
      projects.each do |project|
        repo_name = project.repository.name

        annotated_tag = create_annotated_tag(project, ops)
        if annotated_tag_referenced?(repo_name)
          update_annotated_tag_reference(
            annotated_tag[:sha], repo_name
          )
        else
          create_annotated_tag_reference(
            annotated_tag[:sha], repo_name
          )
        end
      end
    end
  end

  def detach_deployment_tags(api_client)
    @api_client ||= api_client

    if environment.production?
    else
      projects.each do |project|
        repo_name = project.repository.name
        delete_annotated_tag_reference(repo_name) if annotated_tag_referenced?(repo_name)
      end
    end
  end

  def attach_sentry_release
    projects.each do |project|
      if !Sentry.get_release(project.sha).success?
        url = "https://github.com/#{ENV["ORGANISATION"]}/#{project.repository.name}/commit/#{project.sha}"
        body = {
          version: project.sha,
          ref: project.sha,
          url: url,
          commits: [{id: project.sha, message: project.deployment.release.summary}],
          projects: [project.repository.name]
        }
        Sentry.create_release(body)
      end
    end
  end

  private

  def create_annotated_tag(project, ops)
    object_sha = project.sha
    message = "#{project.branch.name}\n"
    tagger_name = ops.name || "Ops".freeze
    tagger_email = "#{ops.slack_username}@#{USER_EMAIL_DOMAIN}"
    tagger_date = Time.now.utc.iso8601

    tag_params = [
      repo(project.repository.name),
      tag_name,
      message,
      object_sha,
      "commit".freeze,
      tagger_name,
      tagger_email,
      tagger_date
    ]

    api_client.create_tag(*tag_params)
  end

  def create_annotated_tag_reference(tag_sha, repo_name)
    api_client.create_ref(repo(repo_name), tag_ref, tag_sha)
  end

  def update_annotated_tag_reference(tag_sha, repo_name)
    api_client.update_ref(repo(repo_name), tag_ref, tag_sha)
  end

  def delete_annotated_tag_reference(repo_name)
    api_client.delete_ref(repo(repo_name), tag_ref)
  end

  def annotated_tag_referenced?(repo_name)
    api_client.ref(repo(repo_name), tag_ref)
    true
  rescue ::Octokit::NotFound
    return false
  end

  def repo(name)
    "#{ReleasesHelper::ORGANISATION}/#{name}"
  end

  def tag_name
    "#{environment.name}_deployed"
  end

  def tag_ref
    "tags/#{tag_name}"
  end
end
