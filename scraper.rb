# require 'nokogiri'
require 'pry'
# require 'mechanize'
require 'watir'
require 'webdrivers'
require 'caxlsx'
require "i18n"
I18n.config.available_locales = :en

def set_variables
  @neighborhood_name = 'tijuca'
  @municipio = 'Rio de janeiro'
  @city_name = 'Rio de Janeiro'
  @bedrooms = 1
  @min_price = 0
  @max_price = 1200
end

def set_webdriver
  # CHROME CONFIG
  # chrome_driver_path = File.expand_path("../..", Dir.pwd)
  # Selenium::WebDriver::Chrome::Service.driver_path=File.join(chrome_driver_path, 'chromedriver.exe')
  options = Selenium::WebDriver::Chrome::Options.new
  client = Selenium::WebDriver::Remote::Http::Default.new
  client.read_timeout = 600
  client.open_timeout = 600
  
  # FIREFOX CONFIG
  # options = Selenium::WebDriver::Firefox::Options.new
  
  # options.add_option(:detach, true)
  # options.add_argument("start-maximized")
  # options.add_preference('webkit.webprefs.loads_images_automatically', false)
  
  # @browser = Watir::Browser.new :firefox, :options => options
  # @browser = Watir::Browser.new :chrome, :options => options, :http_client => client
  @browser = Watir::Browser.new :chrome, headless: true, :http_client => client
end

def viva_real_search
  set_variables
  set_webdriver
  
  url = 'https://www.vivareal.com.br/'
  @browser.goto(url)
  
  form = @browser.form(class: %w(main-search__form js-base-search))
  return false unless form.exist?
  
  sleep(2)
  form.select_list(class: 'js-select-business').option(value: 'rent').select
  form.select_list(class: 'js-select-type').option(value: 'APARTMENT|UnitSubType_NONE,DUPLEX,LOFT,STUDIO,TRIPLEX|RESIDENTIAL|APARTMENT').select
  form.text_field.set(@neighborhood_name)
  sleep(2)

  neighborhood_elements = form.lis(data_type: 'neighborhood')
  neighborhood_elements.each do |ne|
    if (I18n.transliterate(ne.text.split(', ')[0]).downcase == @neighborhood_name.downcase) && (I18n.transliterate(ne.text.split(', ')[1].split(' -')[0]).downcase == @city_name.downcase)
      ne.click
      break
    end
  end
  sleep(2)
  
  form2 = @browser.form
  # min_price = form2.div(class: 'filter-range__container').text_field(id: 'filter-range-from-price')
  # min_price.set(@min_price)
  max_price = form2.div(class: 'filter-range__container').text_field(id: 'filter-range-to-price')
  max_price.set(@max_price)
  form2.div(class: %w(form__pills js-bedrooms-quantity)).ul(class: %w(filter-pills js-container)).button(data_value: @bedrooms.to_s).click
  sleep(3)
  
  total_pages = @browser.lis(class: 'pagination__item', data_type: 'number').last.link.data_page.to_i
  pagina_atual = @browser.link(class: 'js-change-page', data_active: true).data_page.to_i
  proxima_pagina = @browser.link(class: 'js-change-page', data_page: (pagina_atual + 1).to_s)
  
  total_data = []
  # total_data << collect_data
  loop do
    total_data << collect_data
    if pagina_atual == total_pages
      break
    end
    proxima_pagina.click
    sleep(2)
    pagina_atual = @browser.link(class: 'js-change-page', data_active: true).data_page.to_i
    proxima_pagina = @browser.link(class: 'js-change-page', data_page: (pagina_atual + 1).to_s)
    total_pages = @browser.lis(class: 'pagination__item', data_type: 'number').last.link.data_page.to_i
  end
  total_data = total_data.flatten
  
  p = Axlsx::Package.new
  wb = p.workbook
  wb.add_worksheet(:name => 'Planilha 1') do |sheet|
    sheet.add_row ['Área', 'Quartos', 'Suítes', 'Banheiros', 'Vagas', 'Preço', 'Condominio', 'Link']
    total_data.each do |item|
      sheet.add_row [item[:area], item[:rooms], item[:suites], item[:bathrooms], item[:garage_spot], item[:price], item[:condominio], item[:link]]
    end
  end
  p.serialize('result_viva_real.xlsx')
end

def collect_data
  page_data = []
  @browser.execute_script("window.scrollTo(0, document.body.scrollHeight)")
  for i in 0..(@browser.divs(data_type: 'property').length-1)
    properties = @browser.divs(data_type: 'property')[i]
    link = properties.link.href.split('?__vt')[0]
    
    info = properties.div(class: 'property-card__main-content').ul(class: 'property-card__details')
    area = info.li(class: 'property-card__detail-area').text.to_i
    rooms = info.li(class: 'js-property-detail-rooms').text.to_i
    
    suites = info.li(class: 'js-property-detail-suites').text.to_i
    bathrooms = info.li(class: 'js-property-detail-bathroom').text.to_i
    garage_spot = info.li(class: 'js-property-detail-garages').text.to_i
    values = properties.div(class: 'property-card__main-content').section(class: 'property-card__values')
    price = values.div(class: 'js-property-card-prices').text.gsub(/\D/, '').to_i
    
    if values.div(class: 'property-card__price-details--condo').exist?
      condominio = values.div(class: 'property-card__price-details--condo').text.gsub(/\D/, '').to_i
    else
      condominio = 0
    end
    page_data[i] = {
      area: area,
      rooms: rooms,
      suites: suites,
      bathrooms: bathrooms,
      garage_spot: garage_spot,
      price: price,
      condominio: condominio,
      link: link
    }
  end
  page_data
end

def imovelweb_search
  set_variables
  set_webdriver
  
  url = 'https://www.imovelweb.com.br/'
  @browser.goto(url)
  
  form = @browser.form(class: 'layout-container')
  # buy = form.button(data_tracking: "Comprar")
  rent = form.button(data_tracking: "Alquilar")
  rent.click
  advanced_search = form.div(class: %w(button-more-filters css-text-c))
  advanced_search.click
  
  search_container = form.div(class: %w(search-box-container))
  neighborhood = search_container.input(class: %w(rbt-input-main form-control rbt-input)).send_keys('tijuca')
  sleep(2)
  neighborhoods_list = search_container.ul(id: 'typeahead-home').lis

  # neighborhoods_list.each do |n|
  #   name = I18n.transliterate(n.aria_label).downcase.split(', ')
  #   if name[0] == @neighborhood_name.downcase
  #     if name.length == 3
  #       n.click if name[1] == @municipio.downcase && name[2] == @city_name.downcase
  #     elsif name.length == 2
  #       n.click if name[2] == @city_name.downcase
  #     end
  #   end
  # end
  bedrooms = form.div(class: 'room-type-container')
  bedrooms.button(value: '2').click

  # form.div(class: 'price-range-container').input(id: 'price-min').send_keys('1000')
  form.div(class: 'price-range-container').input(id: 'price-max').send_keys('2000')
  form.button(class: %w(submit-filters btn-primary btn-full)).click
  binding.pry
end

def quintoandar_favorites
  set_webdriver
  urls = [
    'https://www.quintoandar.com.br/imovel/892900553',
    'https://www.quintoandar.com.br/imovel/892950628',
    'https://www.quintoandar.com.br/imovel/893022102',
    'https://www.quintoandar.com.br/imovel/893164233',
    'https://www.quintoandar.com.br/imovel/893211498',
    'https://www.quintoandar.com.br/imovel/893239668',
    'https://www.quintoandar.com.br/imovel/893066411',
    'https://www.quintoandar.com.br/imovel/893071261',
    'https://www.quintoandar.com.br/imovel/893170382',
    'https://www.quintoandar.com.br/imovel/893181899',
    'https://www.quintoandar.com.br/imovel/893191826',
    'https://www.quintoandar.com.br/imovel/893245602'
  ]

  list = Array.new(urls.size)
  urls.each_with_index do |url, index|
    @browser.goto(url)

    specs = @browser.div(xpath: '//*[@id="app"]/div/div/main/section/div/div[1]/div/div[2]').child.children
    total_value = @browser.span(xpath: '//*[@id="app"]/div/div/main/section/div/div[2]/section/div/ul/li[6]/div/span').text

    list[index] = [url]
    specs.each do |spec|
      list[index] << spec.span.text
    end
    list[index] << total_value
  end

  # TODO
  # Adicionar um código para gerar na planilha os horários e dias de agendamento

  p = Axlsx::Package.new
  wb = p.workbook
  wb.add_worksheet(:name => 'Planilha 1') do |sheet|
    sheet.add_row ['Url', 'Área', 'Quartos', 'Banheiros', 'Vagas', 'Andar', 'Aceita pet', 'Mobilia', 'Proximo metro', 'Total']
    list.each do |list_item|
      sheet.add_row list_item
    end
  end
  p.serialize('favoritos_quinto_andar.xlsx')
end

def olx_search
  set_webdriver

  # TODO
  # o estado vem sempre como subdomínio
  # ver como escolher a região, zona, bairro
  url = 'https://rj.olx.com.br/rio-de-janeiro-e-regiao/centro/santa-teresa/imoveis/aluguel?pe=1200&bas=1&ros=1'
  @browser.goto(url)

  # ps = preco_minimo
  # pe = preco_maximo
  # ros = quartos_minimo        de 0 a 5, onde 5 = 5 ou mais
  # roe = quartos_maximo        de 0 a 5, onde 5 = 5 ou mais
  # bas = banheiros_minimo      de 0 a 5, onde 5 = 5 ou mais
  # bae = banheiros_maximo      de 0 a 5, onde 5 = 5 ou mais
  # gsp = vagas_garagem         de 0 a 5, onde 5 = 5 ou mais
  # ret = tipo                  pode ser adicionado na url também, adicionando /apartamentos ou /casas ou /aluguel-de-quartos antes dos parâmetros. se escolher mais de um, tem que ser com os códigos abaixo
  # tipo = {
  #   1020: 'apartamentos',
  #   1040: 'casas',
  #   1060: 'quartos',
  # }

  # ss = area_minima
  # se = area_maxima
  # area = {
  #   '0':  '0',
  #   '1':  '30',
  #   '2':  '60',
  #   '3':  '90',
  #   '4':  '120',
  #   '5':  '150',
  #   '6':  '180',
  #   '7':  '200',
  #   '8':  '250',
  #   '9':  '300',
  #   '10': '400',
  #   '11': '500',
  #   '12': 'acima de 500'
  # }

  list = []
  urls = []
  lis = @browser.ul(id: 'ad-list').lis

  puts 'pegando as urls'
  lis.each do |item|
    if item.a(data_lurker_detail: 'list_id').exists?
      urls << item.a.href
    end
  end
  urls.each_with_index do |url, index|
    @browser.goto url
    price = @browser.h2(xpath: '//*[@id="content"]/div[2]/div/div[2]/div[2]/div[7]/div/div[1]/div[2]/h2').text.split('R$')[1].to_i
    condo = @browser.dt(visible_text: 'Condomínio').present? ? @browser.dt(visible_text: 'Condomínio').next_sibling.text.split('R$')[1].to_i : 0
    iptu = @browser.dt(visible_text: 'IPTU').present? ? @browser.dt(visible_text: 'IPTU').next_sibling.text.split('R$')[1].to_i : 0
    area = @browser.dt(visible_text: 'Área útil').present? ? @browser.dt(visible_text: 'Área útil').next_sibling.text.split('m')[0].to_i : 0
    rooms = @browser.dt(visible_text: 'Quartos').present? ? @browser.dt(visible_text: 'Quartos').next_sibling.text.to_i : 0
    bathrooms = @browser.dt(visible_text: 'Banheiros').present? ?  @browser.dt(visible_text: 'Banheiros').next_sibling.text.to_i : 0
    garage = @browser.dt(visible_text: 'Vagas na garagem').present? ? @browser.dt(visible_text: 'Vagas na garagem').next_sibling.text.to_i : 0
    total = condo + price + iptu
    list << [url, area, rooms, bathrooms, garage, total] if total < 1300
    puts "pagina #{index + 1} de #{urls.count}"
  end

  p = Axlsx::Package.new
  wb = p.workbook
  wb.add_worksheet(:name => 'Planilha 1') do |sheet|
    sheet.add_row ['Url', 'Área', 'Quartos', 'Banheiros', 'Vagas', 'Total']
    list.each do |list_item|
      sheet.add_row list_item
    end
  end
  p.serialize('lista_olx.xlsx')
end

olx_search