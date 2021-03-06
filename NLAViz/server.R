library(shiny)
library(RCurl)
library(ggplot2)
library(lme4)
library(data.table)
library(maps)

# Define a server for the Shiny app
shinyServer(function(input, output) {
  # ui buttons
  # outputs slider button
  output$slider <- renderUI({
    sliderInput(inputId="nut",
                label="Choose your nitrogen input (ug/L)",
                value=2500, 
                min=10, 
                max=5000,
                step = 100)
  })
  # outputs checkbox for lake origin: man-made/natural
  output$lake_origin_check <- renderUI({
    dt <- getData()
    lake_choices <- as.character(unique(dt[, LAKE_ORIGIN]))
    checkboxGroupInput(inputId = "lake_origin",
                label = "Choose a lake type",
                choices = lake_choices,
                selected = lake_choices)
  })
  # outputs checkbox for lake depth: <= 4m / > 4m
  output$lake_depth_check <- renderUI({
    dt <- getData()
    lake_choices <- as.character(unique(dt[, check_lake_depth]))
    checkboxGroupInput(inputId = "lake_depth",
                       label = "Choose a lake depth",
                       choices = lake_choices,
                       selected = lake_choices)
  })
  # outputs Nitrogen.gif
  # Will need to change src once in production
  output$nitrogen_gif <- renderUI({
    # HTML format: <IMG SRC="image.gif" ALT="some text" WIDTH=32 HEIGHT=32>
    return(HTML("<img src=\"https://raw.githubusercontent.com/Monsauce/Vizualizing-Nutrients/master/Nitrogen.gif\">"))
  })
  # outputs Dilutions.png
  # will need to change src once in production
  output$dilution <- renderUI({
    # HTML format: <IMG SRC="image.gif" ALT="some text" WIDTH=32 HEIGHT=32>
    return(HTML("<img src = \"https://raw.githubusercontent.com/Monsauce/Vizualizing-Nutrients/master/Dilutions.png\">"))
  })
  
  # reactive functions
  # gets data from NLA_MB in global.R
  getData <- reactive({
    df <- data.table(NLA_MB)
    return(df)
  })
  # filters data based on selection widgets and outputs only necessary columns
  filterData <- reactive({
    dt <- getData()
    dt <- dt[LAKE_ORIGIN %in% input$lake_origin &
               check_lake_depth %in% input$lake_depth]
    # Create an error message when no checkboxes are marked
    validate(
      need(nrow(dt) != 0, "Please check at least one lake type or lake depth option")
    )
    dt <- dt[, list(LON_DD, 
                    LAT_DD, 
                    ECO_NUTA,
                    ni = input$nut)]
    return(dt)
  })
  # Contains model and predicts new values based on slider
  predictData <- reactive({
    dt <- filterData()
    # Create an error message when no checkboxes are marked
    validate(
      need(nrow(dt) != 0, "Please check at least one lake type or lake depth option")
    )
    setnames(dt, old = "ni", new =  c("log10NTL"))
    # Get predictions based on the model
    predictions <- predict(mod, newdata = dt)
    dt[, `:=`(predictions = predictions)]
    return(dt)
  })
  # Plots
  output$CyanoMap <- renderPlot({
    Cyano <- predictData()
    all_states <- map_data("state")
    p <- ggplot()+geom_polygon(data=all_states, aes(x=long, y=lat, group = group),colour="#939597", fill="#939597")+
      geom_point(data=Cyano, aes(colour=ECO_NUTA, x=LON_DD, y=LAT_DD, size = predictions^1.2))+
      theme(axis.text.y = element_blank())+
      theme(axis.ticks = element_blank())+
      theme(axis.text.x = element_blank())+
      theme(axis.title.x = element_blank())+
      theme(axis.title.y = element_blank())+
      theme(panel.grid.major = element_blank())+
      theme(panel.grid.minor = element_blank())+
      theme(panel.background = element_rect(fill = "white"))+
      scale_size_identity()+
      scale_colour_manual(values = c("#C39A6B","#B51F2D", "#009344","#FFF100","#A87B4F","#1B75BB","#74B7E4","#808284","#FEDD4E","#006738","white"))+
      theme(legend.position="none")
      
    
    return(p)
  }, bg="transparent")
  output$intro <- renderText({
    return("Now you try to input nitrogen. Larger circles are larger cyanobacterial blooms. What happens to bloom size as you change the input of nitrogen? Are lakes in some areas affected more or less than others? You can also pick the depth and type of lake to look at. (Nitrogen on a log scale. Data source: US EPA 2009, National Lakes Assessment (2007)).")    
  })
  output$question <- renderText({
    return("The map is color coded for different regions of the U.S. These regions represent lakes with different water quality states, surrounding land use and nutrient levels.")
  })

  
  })


