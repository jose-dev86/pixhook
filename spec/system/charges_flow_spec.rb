require "rails_helper"

RSpec.describe "Fluxo de cobranças no painel", type: :system do
  self.use_transactional_tests = false

  let!(:merchant) { demo_merchant! }

  it "cria uma cobrança pelo formulário e mostra o QR code Pix" do
    visit root_path
    click_on "Criar cobrança", match: :first

    fill_in "Valor (R$)", with: "1.249,90"
    fill_in "Descrição", with: "Notebook"
    click_button "Criar cobrança"

    expect(page).to have_content("Cobrança criada.")
    expect(page).to have_css("h1", text: "Notebook")
    expect(page).to have_content("R$ 1.249,90")
    expect(page).to have_css(".badge--pending", text: "Pendente")
    expect(page).to have_css(".pix__qr svg")

    charge = Charge.last
    expect(find_field("pix-code").value).to eq(charge.pix_copy_paste)
    expect(charge.amount_cents).to eq(124_990)
  end

  it "simula o pagamento e entrega o webhook assinado de verdade" do
    charge = create(:charge, merchant:, description: "Tênis", amount_cents: 15_900)
    visit charge_path(charge)

    click_on "Simular pagamento"

    expect(page).to have_content("Pagamento simulado.")
    within("#charge_summary") { expect(page).to have_css(".badge--paid", text: "Paga") }
    within("#charge_deliveries") do
      expect(page).to have_content("Cobrança paga")
      expect(page).to have_css(".badge--delivered", text: "Entregue")
      expect(page).to have_content("HTTP 204")
    end
    expect(charge.webhook_events.last.reload).to be_delivered
  end

  it "atualiza a tela em tempo real quando a cobrança é paga por fora (API)" do
    charge = create(:charge, merchant:, description: "Mochila")
    visit charge_path(charge)
    expect(page).to have_css(".badge--pending")
    page.execute_script("window.__sameDocument = true")

    charge.pay!

    within("#charge_summary") { expect(page).to have_css(".badge--paid", text: "Paga") }
    within("#charge_deliveries") { expect(page).to have_css(".badge--delivered", text: "Entregue") }
    expect(page.evaluate_script("window.__sameDocument")).to be true
  end

  it "copia o Pix copia e cola para a área de transferência" do
    charge = create(:charge, merchant:)
    visit charge_path(charge)

    click_on "Copiar"

    expect(page).to have_button("Copiado!")
    expect(clipboard_text).to eq(charge.pix_copy_paste)
  end

  it "estorna uma cobrança paga" do
    charge = create(:charge, merchant:, description: "Fone").tap(&:pay!)
    visit charge_path(charge)

    click_on "Estornar"

    within("#charge_summary") { expect(page).to have_css(".badge--refunded", text: "Estornada") }
    within("#charge_deliveries") { expect(page).to have_content("Cobrança estornada") }
  end

  it "filtra a lista por status" do
    create(:charge, merchant:, description: "Camiseta")
    create(:charge, merchant:, description: "Bermuda").tap(&:pay!)

    visit charges_path
    expect(page).to have_content("Camiseta").and have_content("Bermuda")

    click_on "Paga"
    expect(page).to have_content("Bermuda")
    expect(page).to have_no_content("Camiseta")
    expect(page).to have_css(".tab--active", text: "Paga")
  end

  it "reenvia pelo painel um webhook que estava na fila de mortos" do
    charge = create(:charge, merchant:, description: "Relógio")
    event = WebhookEvent.create!(merchant:, charge:, event_type: "charge.paid", payload: { event: "charge.paid" }, status: :dead, last_error: "HTTP 500")

    visit root_path
    within(".card", text: "Precisa de atenção") do
      expect(page).to have_content("HTTP 500")
      click_on "Reenviar"
    end

    expect(page).to have_content("Webhook enfileirado para reenvio.")
    expect(event.reload).to be_delivered
  end

  it "mostra os indicadores da visão geral em reais" do
    create(:charge, merchant:, amount_cents: 4_990).tap(&:pay!)
    create(:charge, merchant:, amount_cents: 1_000)

    visit root_path

    within(".kpi", text: "Recebido") do
      expect(page).to have_css(".kpi__value", text: "R$ 49,90")
      expect(page).to have_content("1 cobrança paga")
    end
    within(".kpi", text: "A receber") { expect(page).to have_css(".kpi__value", text: "R$ 10,00") }
    within(".kpi", text: "Entrega de webhooks") { expect(page).to have_css(".kpi__value", text: "100%") }
  end

  context "no celular", :mobile do
    it "adapta o menu e a tabela à tela pequena" do
      create(:charge, merchant:, description: "Boné")
      visit charges_path

      expect(page).to have_content("Boné")
      expect(page).to have_no_css(".nav__link span", text: "Cobranças")
      expect(page).to have_no_css("th", text: "WEBHOOKS")
      expect(page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")).to be true
    end
  end
end
