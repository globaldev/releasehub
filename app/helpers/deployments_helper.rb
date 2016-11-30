module DeploymentsHelper
  DEFAULT_NOTIFY_IDS = ENV["DEFAULT_NOTIFY_IDS"]
  DEFAULT_CHANNEL = ENV["DEFAULT_CHANNEL"]
  USER_EMAIL_DOMAIN = ENV["RH_USER_EMAIL_DOMAIN"]

  def attach_deployment_tags(deployment, ops)
    if deployment.environment.production?

    else
      tag_name = "#{deployment.environment.name}_deployed"

      deployment.projects.map do |project|
        repo_name = project.repository.name

        annotated_tag = create_annotated_tag(tag_name, project, ops)
        if annotated_tag_referenced?(tag_name, repo_name)
          update_annotated_tag_reference(
            tag_name, annotated_tag[:sha], repo_name
          )
        else
          create_annotated_tag_reference(
            tag_name, annotated_tag[:sha], repo_name
          )
        end
      end
    end
  end

  def detach_deployment_tags(deployment)
    if deployment.environment.production?
    else
      tag_name = "#{deployment.environment.name}_deployed"

      deployment.projects.map do |project|
        repo_name = project.repository.name
        if annotated_tag_referenced?(tag_name, repo_name)
          delete_annotated_tag_reference(tag_name, repo_name)
        else
          false
        end
      end
    end
  end

  def create_annotated_tag(tag_name, project, ops)
    object_sha = project.sha
    message = "#{project.branch.name}\n"
    tagger_name = ops.name
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

    client.create_tag(*tag_params)
  end

  def create_annotated_tag_reference(tag_name, tag_sha, repo_name)
    client.create_ref(repo(repo_name), tag_ref(tag_name), tag_sha)
  end

  def update_annotated_tag_reference(tag_name, tag_sha, repo_name)
    client.update_ref(repo(repo_name), tag_ref(tag_name), tag_sha)
  end

  def delete_annotated_tag_reference(tag_name, repo_name)
    client.delete_ref(repo(repo_name), tag_ref(tag_name))
  end

  def annotated_tag_referenced?(tag_name, repo_name)
    client.ref(repo(repo_name), tag_ref(tag_name))
    true
  rescue ::Octokit::NotFound
    return false
  end

  private

  def repo(name)
    "#{ReleasesHelper::ORGANISATION}/#{name}"
  end

  def tag_ref(name)
    "refs/tags/#{name}"
  end
end
