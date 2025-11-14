puts 'Seeding DevTracker data...'

User.find_or_create_by!(email: 'admin@example.com') do |user|
  user.password = 'Password123!'
  user.password_confirmation = 'Password123!'
  user.first_name = 'Avery'
  user.last_name = 'Admin'
  user.role = :admin
  user.time_zone = 'UTC'
end

team = User.find_or_create_by!(email: 'pm@example.com') do |user|
  user.password = 'Password123!'
  user.password_confirmation = 'Password123!'
  user.first_name = 'Priya'
  user.last_name = 'Manager'
  user.role = :lead
  user.time_zone = 'UTC'
end

staff = User.find_or_create_by!(email: 'dev@example.com') do |user|
  user.password = 'Password123!'
  user.password_confirmation = 'Password123!'
  user.first_name = 'Devon'
  user.last_name = 'Builder'
  user.role = :developer
  user.time_zone = 'UTC'
end

clients = [
  { name: 'Northwind Communities', code: 'NW', contact_name: 'Laura Chen', contact_email: 'laura@northwind.com', priority_level: :strategic },
  { name: 'Summit Hospitality', code: 'SH', contact_name: 'Jacob Mills', contact_email: 'jacob@summithq.com', priority_level: :elevated },
  { name: 'Brightside Holdings', code: 'BH', contact_name: 'Shelly Nguyen', contact_email: 'shelly@brightside.com', priority_level: :standard }
]

clients.each do |attrs|
  Client.find_or_create_by!(code: attrs[:code]) do |client|
    client.assign_attributes(attrs.merge(status: :active, timezone: 'UTC', notes: 'Key enterprise client.'))
  end
end

primary_client = Client.find_by!(code: 'NW')

client_user = User.find_or_create_by!(email: 'client@northwind.com') do |user|
  user.password = 'Password123!'
  user.password_confirmation = 'Password123!'
  user.first_name = 'Nora'
  user.last_name = 'Client'
  user.role = :client
  user.time_zone = 'UTC'
  user.client = primary_client
end

client_user.update!(client: primary_client) if client_user.client != primary_client

Client.all.each do |client|
  project = client.projects.find_or_create_by!(name: "#{client.name} Dev Tracker") do |proj|
    proj.start_date = Date.current.beginning_of_month
    proj.end_date = proj.start_date + 60.days
    proj.estimated_cost = rand(75_000..150_000)
    proj.description = "#{client.name} Modernization"
  end

  project.start_date ||= Date.current.beginning_of_month
  project.end_date ||= project.start_date + 60.days
  project.save! if project.changed?

  sprint_labels = ['Web App', 'Mobile App', 'API Integrations']
  sprints = sprint_labels.each_with_index.map do |name, index|
    sprint_record = project.sprints.find_or_create_by!(name:) do |sprint|
      sprint.goal = "#{name} deliverables for #{client.code}"
      sprint.start_date = project.start_date + (index * 14).days
      sprint.end_date = sprint.start_date + 13.days
      sprint.cost = rand(10_000..25_000)
    end
    sprint_record
  end

  3.times do |index|
    item = client.agenda_items.find_or_initialize_by(title: "#{client.name} Initiative #{index + 1}")
    item.attributes = {
      assignee: [team, staff].sample,
      description: 'Partner request covering sprint work, enhancements, and post-launch support.',
      work_stream: AgendaItem.work_streams.keys.sample,
      status: AgendaItem.statuses.keys.sample,
      priority_level: AgendaItem.priority_levels.keys.sample,
      complexity: rand(1..5),
      due_on: Date.current + rand(-3..14).days,
      requested_by: client.contact_name,
      requested_by_email: client.contact_email,
      estimated_cost: rand(5_000..20_000),
      paid: [true, false].sample,
      notes: 'Auto-generated seed data',
      project: project,
      sprint: sprints.sample
    }
    item.save!

    item.agenda_messages.find_or_create_by!(kind: :status_update, user: team, body: 'Initial kickoff complete.')
  end
end

puts 'Seed complete. Default admin: admin@example.com / Password123!'
