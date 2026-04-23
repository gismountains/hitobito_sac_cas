return unless Rails.env.development?

Rails.application.config.to_prepare do
  Person.class_eval do
    DEMO_ROOT_EMAILS = ["demo"].freeze

    def root?
      email == Settings.root_email || DEMO_ROOT_EMAILS.include?(email)
    end
  end
end
