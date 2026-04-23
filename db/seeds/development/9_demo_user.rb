demo = Person.find_or_initialize_by(email: "demo")
demo.assign_attributes(
  first_name: "Demo",
  last_name: "User",
  password: "demo",
  password_confirmation: "demo",
  confirmed_at: Time.current
)
demo.save!(validate: false)
