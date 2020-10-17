require 'nokogiri'
require 'pry'
require 'mechanize'
require 'watir'
require 'webdrivers'
require 'caxlsx'
require "i18n"
I18n.config.available_locales = :en

def set_variables
  @neighborhood_name = 'tijuca'
  @municipio = 'Rio de janeiro'
  @city_name = 'Rio de Janeiro'
  @bedrooms = 2
  @min_price = 0
  @max_price = 3000
end

def set_webdriver
  # chrome_driver_path = File.expand_path("../..", Dir.pwd)
  # Selenium::WebDriver::Chrome::Service.driver_path=File.join(chrome_driver_path, 'chromedriver.exe')
  
  options = Selenium::WebDriver::Chrome::Options.new
  # options.add_option(:detach, true)
  options.add_argument("start-maximized")
  # options.add_preference('webkit.webprefs.loads_images_automatically', false)

  @browser = Watir::Browser.new :chrome, :options => options
end

def viva_real
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
  sleep(5)

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
  p.serialize('result.xlsx')
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

def imovelweb
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

imovelweb