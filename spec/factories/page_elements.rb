FactoryBot.define do
  factory :page_element do
    name { "#{Faker::Science.unique.element}_#{Faker::Science.unique.element}".downcase }
  end

  factory :short_text_page_element, parent: :page_element do
    content_type { I18n.t( 'admin.elements.short_text' ) }
  end

  factory :long_text_page_element, parent: :page_element do
    content_type { I18n.t( 'admin.elements.long_text' ) }
  end

  factory :image_page_element, parent: :page_element do
    content_type { I18n.t( 'admin.elements.image' ) }
  end

  factory :html_page_element, parent: :page_element do
    content_type { I18n.t( 'admin.elements.html' ) }
  end
end
