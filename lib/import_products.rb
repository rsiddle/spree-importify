require 'csv'
require 'active_support'
require 'action_controller'
include ActionDispatch::TestProcess
require 'yaml'

# class AuditLogger < Logger
  # def format_message(severity, timestamp, progname, msg)
    # "#{timestamp.to_formatted_s(:db)} #{severity} #{msg}\n" 
  # end 
# end

class ImportProducts
  
    def initialize()

      remove_products

      #Images are below SPREE/vendor/import/productsXXXX/
      # if there are more than one, take lexically last
      
      @dir = Dir.glob(File.join(Rails.root, "vendor", "import","products*" )).last
      puts "Loading from #{@dir}"

      # logfile = File.open(File.join(Rails.root.to_s, "log","product-import-#{Time.now.to_s(:db)}.log"), 'a')    
      # @audit_log = AuditLogger.new(logfile)
      
      # @audit_log.info "Loading from #{@dir}"

      # one root taxonomy supported only. Must be set before (eg rake db:load_file)
      @taxonomy = Taxonomy.find(:first)
      throw "No Taxonomy found, create by sample data (rake db:data:load) or override set_taxon method" unless @taxonomy
      
      root = @taxonomy.root  # the root of a taxonomy is a taxon , usually with the same name (?)
      if root == nil 
        @taxonomy.root = Taxon.new( :name => @taxonomy.name , :taxonomy_id => @taxonomy.id )
        @taxonomy.save!
      end

      # assuming you have data from another software which generates csv (or tab delimited) data _with headers_
      # We want to map those "external" headers to the spree product names: That is the mapping below
      # mapping to nil, means that column is digarded (thus possibly saving you to remove colums from the import file)
      #@mapping = YAML.load_file(  File.join( @dir , "mapping.yml") )
      #or edit something like this
      
      @mapping = {
        'prototype' 		    => :prototype,
        'parent_sku'		    => :parent_sku,
        'sku' 				      => :sku,
        'permalink'			    => :permalink,
        'name' 				      => :name,
        'description' 		  => :description,
        'price' 			      => :price,
        'option' 			      => :option,
        'Width' 			      => :width,
        'Length'			      => :depth,
        'Weight' 			      => :weight,
        'quantity' 			    => :quantity,
        'brand' 			      => :brand,
        'category' 			    => :category1,
#       'cat2' 			      => :category2,
        'shipping_category' => :shipping_category,
        'tax_category' 		  => :tax_category,
        'unit_price' 		    => :unit_price,
        'delete'        	  => :delete,
        'image' 			      => :image,
        'image2' 			      => :image2,
        'image3' 			      => :image3,
        'page_title'		    => :meta_title,
        'meta_description'  => :meta_description,
        'meta_keywords'		  => :meta_keywords,
        'VE1' 				      => 	nil
      }
  end
  
  def at_in( sym , row )
    index = @header.index(@mapping.index(sym))
    return nil unless index
    return row[index]
  end

  #override if you have your categories encoded in one field or in any other way
  def get_categories(row)
    categories = []
    cat = at_in(:category1 , row) if at_in(:category1 , row) # should invent some loop here
    categories << cat if cat
    cat = at_in(:category2 , row) if at_in(:category2 , row)# but we only support
    categories << cat if cat
    cat = at_in(:category3 , row) if at_in(:category3 , row)# three levels, so there you go
    categories << cat if cat
    categories
  end
  
  # TODO: For some reason this method seems to duplicate the categories
  def set_taxon(product , row)
    categories = get_categories(row)
    if !categories.empty?
      
      #puts "Categories #{categories.join('/')}"
      #puts "Taxonomy #{@taxonomy} #{@taxonomy.name}"
      @parent = @taxonomy.root  # the root of a taxonomy is a taxon , usually with the same name (?)
      #puts "Root #{parent} #{parent.id} #{parent.name}"
      categories.each do |cat|
        taxon = Taxon.find_by_name(cat)
        unless taxon
          puts "Creating -#{cat}-"
          taxon = Taxon.create!(:name => cat , :taxonomy_id => @taxonomy.id , :parent_id => @parent.id ) 
          #@audit_log.error "Creating taxon: #{cat}"
        end
        @parent = taxon
      #puts "Taxon #{cat} #{parent} #{parent.id} #{parent.name}"
      end
      
      product.taxons.each do |t|
        if t.name == @parent.name
          puts "Taxons already set: #{@parent.name}"
        else
          product.taxons << @parent
        end
      end
      
    else
      #@audit_log.error "No category for SKU: #{at_in(:sku, row)} in row (#{row})"
      puts "No category for SKU: #{at_in(:sku, row)} in row (#{row})"
      return
    end
  end
  
  def set_category(product , row)
    category = Taxon.find_by_name(at_in(:category1, row))
    if category
       product_category = product.taxons.select {|t| t.parent.name == 'Categories' }.first.try(:name)

      if product_category == category.name
        puts "Category Already Set"
      else
        puts "Setting Category: #{category.name}"
        product.taxons << category
      end
    else
      puts "You need to create this category before trying to assign a product to it"
      #@audit_log.error "Can't find category: #{brnd}"
    end
  end
  
  def set_brand(product , row)
    brand = Taxon.find_by_name(at_in(:brand, row))
    if brand
       product_brand = product.taxons.select {|t| t.parent.name == 'Brands' }.first.try(:name)

      if product_brand == brand.name
        puts "Brand Already Set"
      else
        puts "Setting Brand: #{brand.name}"
        product.taxons << brand
      end
    else
      puts "You need to create this brand before trying to assign a product to it"
      #@audit_log.error "Can't find brand: #{brnd}"
    end
  end
  
  # Set the shipping category by name
  def set_shipping_category(product, row)
    shipping_category = at_in(:shipping_category, row) if at_in(:shipping_category,row)
    ship_category = ShippingCategory.find_by_name(shipping_category)
    product.shipping_category = ship_category
    #@audit_log.info "Set Shipping Category: #{product.sku} = #{ship_category.name}" if at_in(:shipping_category,row)
    #@audit_log.warn "Set Shipping Category: #{product.sku} = NOT SET" if !at_in(:shipping_category,row)
  end
  
  # Set the shipping center by name
  def set_shipping_center(product, row)
    s_center = at_in(:shipping_center, row) if at_in(:shipping_center,row)
    ship_center = ShipmentCenter.find_by_name(s_center)
    product.shipment_center = ship_center
    #@audit_log.info "Set Ship Centre: #{product.sku} = #{ship_center.name}" if at_in(:shipping_center,row)
    #@audit_log.warn "Set Ship Centre: #{product.sku} = NOT SET" if !at_in(:shipping_center,row)
  end
  
  # Set the tax category by name
  def set_tax_category(product, row)
    tax_category = at_in(:tax_category, row) if at_in(:tax_category,row)
    tax_cat = TaxCategory.find_by_name(tax_category)
    product.tax_category = tax_cat
    #@audit_log.info "Set Tax Category: #{product.sku} = #{tax_cat.name}" if at_in(:tax_category,row)
    #@audit_log.warn "Set Tax Category: #{product.sku} = NOT SET" if !at_in(:tax_category,row)
  end
  
  # Get the product by sku
  def get_product( row )
    puts "get product row:" + row.join("--")
    variant = Variant.find_by_sku( at_in(:sku , row ) )
    
    prod = Product.find_by_name( at_in(:name , row ) )
    puts variant
    
    if !variant.nil?
      puts "Found Variant by SKU: #{at_in(:sku,row)} "
      variant.product 
    elsif !prod.nil?
      puts "Found Product by Name: #{at_in(:name,row)} "
      prod
    else        
        puts "Creating new product harness."
        p = Product.find_or_create_by_name(  :name => "sku" , :price => 5  , :sku => "sku")
        p.save!
        master = Variant.find_by_sku("sku")
        master.product = Product.find_by_name("sku")
        master.save
        Product.find_by_name("sku")
    end
  end
  
  # For testing
  # Does not remove dependencies such as product properties etc.
  def remove_products
    check_admin_user
    return unless remove_products?
    while first = Product.first
      first.delete
    end
    while first = Variant.first
      first.delete
    end
#    while first = Taxon.first
#      first.delete
#    end
  end

  #these are common attributes to product & variant (in fact prod delegates to master variant)
  # so it will be called with either
  def set_attributes_and_image( prod , row )
  
    set_sku(prod,row)
    
    if prod.class == Product
      prod.name        = at_in(:name,row) if at_in(:name,row)
      prod.description = at_in(:description, row) if at_in(:description, row)
      set_prototype_properties(prod,row)
      set_brand(prod,row) if at_in(:brand, row)
      set_taxon(prod,row)
      set_category(prod,row)
      set_permalink(prod,row)
      set_product_position(prod,row)
      set_shipping_category(prod,row) if at_in(:shipping_category, row)
      set_tax_category(prod,row) if at_in(:tax_category, row)
      set_on_hand(prod,row)
    end

		
    # Add product and variations attributes
    set_weight(prod,row)
    set_dimensions(prod, row)
    set_available(prod, row)
	
    set_price(prod, row)
    set_unit_price(prod, row)
    add_image(prod, row)
  end
  
  # lots of little setters. if you need to override
  def set_sku(prod,row)
    prod.sku = at_in(:sku,row) if at_in(:sku,row) 
  end
  
  def set_product_position(prod,row)
    prod.position = at_in(:position,row) if at_in(:position,row) 
  end
  
  def set_on_hand(prod,row)
    prod.on_hand = at_in(:quantity,row) if at_in(:quantity,row) 
  end
  
  # Mass delete or un-delete products (and variants)
  def set_destroy(prod,row)
    to_delete = at_in(:delete,row) if at_in(:delete,row) 
    if to_delete == "1"
	  puts "Deleting: #{prod}"
    #@audit_log.info "Deleting product: #{prod}"
	  prod.deleted_at = Time.now()
		prod.variants.each do |v|
		  v.deleted_at = Time.now()
		  v.save
		end
	elsif to_delete == "0"
	  puts "Un-deleting: #{prod}"
    #@audit_log.info "Deleting product: #{prod}"
	  prod.deleted_at = nil
		prod.variants.each do |v|
		  v.deleted_at = nil
		  v.save
		end
	end
  end
  
  # Set up product with a Prototype if :prototype field is available
  def set_prototype_properties(prod,row)
    prototype_id = at_in(:prototype,row) if at_in(:prototype,row)
    if prototype = Prototype.find_by_name(prototype_id)
      ##@audit_log.info "Setting Prototype: #{prototype.name}"
      puts "Setting Prototype: #{prototype.name}"
      prototype.properties.each do |property|
        prod.product_properties.create(:property => property)
      end
      prod.option_types = prototype.option_types
    else
      puts "Prototype \"#{at_in(:prototype,row)}\" not found!"
    end
  end
  
  ## Start setting product meta data ##
  
  # ["meta_title", "meta_description", "meta_keywords"].each do |prop|
    # define_method "set_#{prop}" do |prod,row|
		# prod.send("#{prop}=",at_in(":#{prop}",row)) if at_in(":#{prop}",row)
    # end
  # end
  
  def set_meta_title(prod,row)
    prod.meta_title  = at_in(:meta_title,row) if at_in(:meta_title,row) 
  end
  
  def set_meta_description(prod,row)
    prod.meta_description  = at_in(:meta_description,row) if at_in(:meta_description,row) 
  end
  
  def set_meta_keywords(prod,row)
    prod.meta_keywords  = at_in(:meta_keywords,row) if at_in(:meta_keywords,row) 
  end
  
  ## End of setting product meta data ##
  
  
  def set_permalink(prod,row)
    begin
      perma = at_in(:permalink,row) if at_in(:permalink,row) 
      perma = prod.name.downcase.gsub(/\s+/, '-').gsub(/[^a-zA-Z0-9_]+/, '-') unless perma
      #@audit_log.warn "Set Permalink: #{product.sku} = #{perma}" if at_in(:perma,row)
      prod.permalink = perma if perma
    rescue
      puts "Error: Permalink already taken"
      return
    end

  end
  
  def set_weight(prod,row)
    prod.weight = at_in(:weight,row) if at_in(:weight,row) 
  end
  
  def set_available(prod,row)
    prod.available_on = Time.now - 90000 unless prod.available_on # over a day, so to show immediately
  end
  
  def set_price(prod, row)
    price = at_in(:web_price,row )
    price = at_in(:price,row ) unless price
    prod.price = price if price
  end
  
  def set_unit_price(prod, row)
    cost_price = at_in(:unit_price, row)
    prod.cost_price = cost_price if at_in(:unit_price,row)
  end
  
  def set_dimensions(prod, row)
    prod.height = at_in(:height,row) if at_in(:height,row) 
    prod.width  = at_in(:width,row)  if at_in(:width,row) 
    prod.depth  = at_in(:depth,row)  if at_in(:depth,row) 
  end
  
  def add_image(prod , row )
    files = Array.new(3)
    files << has_image(row)
    files << has_image_two(row)
    files << has_image_three(row)
	
    for file_name in files
          
      puts "File: #{file_name}"
      #@audit_log.info "File: #{file_name}"
      if file_name
        if file_name && FileTest.exists?(file_name)
            #@audit_log.info "Image/File name correct"
          else
            #@audit_log.error "Image/File mismatch: SKU(#{prod.sku}) - #{file_name} / #{file_name}"
        end
        
        type = file_name.split(".").last
        i = Image.new(:attachment => fixture_file_upload(file_name, "image/#{type}" ))                        
        i.viewable_type = "Product" 
        # link main image to the product
        i.viewable = prod
        prod.images << i 
        
        if prod.class == Variant
          i = Image.new(:attachment => fixture_file_upload(file_name, "image/#{type}" ))                        
          i.viewable_type = "Product" 
          prod.product.images << i
        end
      end
    end
  end
  
  def has_image(row)
    file_name = at_in(:image , row )
	
    # if there is no file don't try to upload.
    if file_name == nil
     return false
    end
	
    file = find_file(file_name) 
    return file if file
    return find_file(file_name + "")
  end
  
  def has_image_two(row)
    file_name = at_in(:image2 , row )
	
    # if there is no file don't try to upload.
    if file_name == nil
     return false
    end
	
    file = find_file(file_name) 
    return file if file
    return find_file(file_name + "")
  end
  
  def has_image_three(row)
    file_name = at_in(:image3 , row )
	
    # if there is no file don't try to upload.
    if file_name == nil
     return false
    end
	
    file = find_file(file_name) 
    return file if file
    return find_file(file_name + "")
  end

  # use (rename to has_image) to have the image name same as the sku
  def has_image_sku(row)
    sku = at_in(:sku,row)
    return find_file( sku)
  end

  # recursively looks for the file_name you've given in you @dir directory
  # if not found as is, will add .* to the end and look again 
  def find_file name
    file = Dir::glob( File.join(@dir , "**", "*#{name}" ) ).first
    return file if file
    Dir::glob( File.join(@dir , "**", "*#{name}.*" ) ).first
  end
  
  def is_line_variant?(sku , index) #or file end
    #puts "variant product -#{name}-"
    return false if (index >= @data.length) 
    row = @data[index]
    return false if row == nil
    variant = at_in( :parent_sku, row )
    return false if variant == nil	
    #puts "variant name -#{variant}-"
    return false unless sku
    #puts "variant return #{ name == variant[ 0 ,  name.length ] }"
    return sku == variant[ 0 ,  sku.length ] 
  end
    
  # read all variants of the product (using is_line_variant? above)
  # uses the :option (mapped) attribute of the product row to find/create an OptionType
  # and the same :option attribute to create OptionValues on the Variants 
  def slurp_variants(prod , index)
    return index unless is_line_variant?(prod.sku , index ) 
    #need an option type to create options, create dumy for now
    prod_row = @data[index - 1]
    option = at_in( :option , prod_row )
    option = prod.name unless option
    puts "Option type -#{option}-"
    option_type  = OptionType.find_or_create_by_name_and_presentation(option , option) 
    product_option_type = ProductOptionType.new(:product => prod, :option_type => option_type)
    product_option_type.save!
    prod.reload
    while is_line_variant?(prod.sku , index )
      puts "variant slurp index " + index.to_s
      row = @data[index]
      option_value = at_in( :option , row )
      option_value = at_in( :name , row ) unless option_value
      puts "variant option -#{option_value}-"
      option_value = OptionValue.create( :name         => option_value, :presentation => option_value,
                                        :option_type  => option_type )
      variant = Variant.create( :product => prod )  # create the new variant
      variant.option_values << option_value         # add the option value
      set_attributes_and_image( variant , row )     #set price and the other stuff
      prod.variants << variant                      #add the variant (not sure if needed)
      index += 1
    end
    return index 
  end
  
  def run
    Dir.glob(File.join(@dir , '*.csv')).each do |file|
      puts "Importing file: " + file
      ActiveRecord::Base.transaction do
        load_file( file )
      end
    end
  end
  
  #If you want to write your own task or wrapper, this is the main entry point
  def load_file full_name
    file = CSV.open( full_name ,  { :col_sep => ","} ) 
    @header = file.shift
    @data = file.readlines
    #puts @header
    @header.each do |col|
      puts "col=#{col}= mapped to =#{@mapping[col]}="
    end
    index = 0
    while index < @data.length
      row = @data[index]
      #puts "row is " + row.join("--")
      @mapping.each  do |key,val|
        #puts "Row:#{val} at #{@mapping.index(val)} is --#{@header.index(@mapping.index(val))}--value---"
        #puts "--#{at_in(val,row)}--" if @header.index(@mapping.index(val))
      end
      prod = get_product(row)
      set_attributes_and_image( prod , row )
      set_destroy(prod,row)
      
      #puts "saving -" + prod.description + "-  at " + at_in(:price,row) #if at_in(:price,row) == "0"
      prod.save!
      throw "No master for #{prod.name}" if prod.master == nil 
      #@audit_log.error "No master for #{prod.name}" if prod.master == nil 
      
      puts "Saved: " + prod.sku + " - " + prod.name # + " -  at " + at_in(:price,row) #if at_in(:price,row) == "0"
      #@audit_log.info "Saved product: #{prod.sku}"
      #Check for variants
      
	    index = slurp_variants(prod , index + 1) #read variants if there are, returning the last read line
	 
    end

  end
  
  #make sure there is an admin user
  def check_admin_user(password="spree123", email="spree@example.com")
      admin = User.find_by_login(email) ||  User.create(  :password => password,
														  :password_confirmation => password,
														  :email => email, 
														  :login => email  )
      # create an admin role and and assign the admin user to that role
      admin.roles << Role.find_or_create_by_name("admin")
      admin.save!
  end
  
end