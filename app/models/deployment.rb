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

  def repo_names
    projects.map { |project| project.repository.name }.join(",")
  end

  def notify_people?
    NOTIFY_STATUS.include?(status_id)
  end

  def last_operator
    operation_logs.last
  end

  def deploy(ops, api_client)
    attach_deployment_tags(ops, api_client, "")
  end

  def attach_deployment_tags(ops, api_client)
    @api_client ||= api_client

    if environment.production?

    else
      projects.each do |project|
        tag = Tag.new(project, ops)

        annotated_tag = create_annotated_tag(tag)

        if annotated_tag_referenced?(tag.repo, tag.reference)
          update_annotated_tag_reference(
            tag.repo, tag.reference, annotated_tag[:sha]
          )
        else
          create_annotated_tag_reference(
            tag.repo, tag.reference, annotated_tag[:sha]
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
        tag = Tag.new(project, ops)

        delete_annotated_tag_reference(tag.repo, tag.reference) if annotated_tag_referenced?(tag.repo, tag.reference)
      end
    end
  end

  private

  def create_annotated_tag(tag)
    api_client.create_tag(*create_tag_params(tag))
  end

  def create_annotated_tag_reference(repo_name, tag_ref, tag_sha)
    api_client.create_ref(repo_name, tag_ref, tag_sha)
  end

  def update_annotated_tag_reference(repo_name, tag_ref, tag_sha)
    api_client.update_ref(repo_name, tag_ref, tag_sha)
  end

  def delete_annotated_tag_reference(repo_name, tag_ref)
    api_client.delete_ref(repo_name, tag_ref)
  end

  def annotated_tag_referenced?(repo_name, tag_ref)
    api_client.ref(repo_name, tag_ref)
    true
  rescue ::Octokit::NotFound
    return false
  end

  def create_tag_params(tag)
    [
      tag.repo,
      tag.name,
      tag.message,
      tag.sha,
      "commit".freeze,
      tag.tagger_name,
      tag.tagger_email,
      tag.date
    ]
  end
end
