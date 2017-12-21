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

  NOTIFY_STATUS = Set[Status::DEPLOYED, Status::ROLLBACK]

  after_update :update_ansible_db

  def repo_names
    projects.map { |project| project.repository.name }.join(",")
  end

  def notify_people?
    NOTIFY_STATUS.include?(status_id)
  end

  def last_operator
    operation_logs.last
  end

  def update_ansible_db
    if status.id == Status::DEPLOYING
      projects.each do |project|
        Ansible.update_sha(environment, project.repository.name, project.sha)
      end
    end

    if status.id == Status::ROLLBACK
      projects.each do |project|
        Ansible.rollback_sha(environment, project.repository.name)
      end
    end
  end
end
