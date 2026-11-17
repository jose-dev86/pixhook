require "rails_helper"

RSpec.describe "Alternar modo claro e escuro", type: :system do
  self.use_transactional_tests = false

  before { demo_merchant! }

  def theme = page.evaluate_script("document.documentElement.dataset.theme")
  def background = page.evaluate_script("getComputedStyle(document.body).backgroundColor")

  it "troca o tema, lembra a escolha e mantém entre páginas" do
    visit root_path
    expect(background).to eq("rgb(246, 248, 251)")

    click_on "Usar modo escuro"
    expect(theme).to eq("dark")
    expect(background).to eq("rgb(11, 17, 32)")
    expect(page).to have_button("Usar modo claro")

    click_on "Cobranças"
    expect(page).to have_css("h1", text: "Cobranças")
    expect(theme).to eq("dark")

    visit root_path
    expect(theme).to eq("dark")

    click_on "Usar modo claro"
    expect(theme).to eq("light")
    expect(background).to eq("rgb(246, 248, 251)")
  end
end
