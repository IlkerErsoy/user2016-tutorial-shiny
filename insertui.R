library(shiny)
library(ggplot2)
library(htmltools)

ui <- fluidPage(
  h2("insertUI demo"),
  sidebarLayout(
    sidebarPanel(
      fileInput("file", "Upload data"),
      # This will hold column dropdowns and "Add plot" button
      uiOutput("column_ui")
    ),
    mainPanel(
      # This <div> will hold all of the plots we're going to
      # dynamically add. It's going to be super fun!
      div(id = "plot_container")
    )
  ),
  # Disable fading effect when processing
  tags$style(".recalculating { opacity: 1; }")
)

server <- function(input, output, session) {
  dataset <- reactive({
    # dataset() can't be fulfilled if no file was uploaded
    req(input$file)
    
    # read.csv the uploaded file. If it fails, squelch the
    # error by using req(FALSE), and show the error using a
    # notification instead. Not sure this is good or evil.
    tryCatch(
      read.csv(input$file$datapath[1]),
      error = function(e) {
        showNotification(
          ui = tagList(strong("Error:"), conditionMessage(e)),
          type = "error"
        )
        req(FALSE)
      }
    )
  })
  
  # Let user choose columns, and add plot.
  output$column_ui <- renderUI({
    choices <- c("Choose one" = "", names(dataset()))
    tagList(
      selectInput("xvar", "X variable", choices),
      selectInput("yvar", "Y variable", choices),
      conditionalPanel("input.xvar && input.yvar",
        actionButton("addplot", "Add plot")
      )
    )
  })
  
  # One of the very few times you'll see me create a non-reactive
  # session-level variable, and mutate it from within an observer
  plot_count <- 0
  
  # Add a plot when addplot is clicked
  observeEvent(input$addplot, {
    plot_count <<- plot_count + 1
    
    id <- paste0("plot", plot_count)
    # Take a static snapshot of xvar/yvar; the renderPlot we're
    # creating here cares only what their values are now, not in
    # the future.
    xvar <- input$xvar
    yvar <- input$yvar
    
    output[[id]] <- renderPlot({
      df <- brushedPoints(dataset(), input$brush, allRows = TRUE)
      
      ggplot(df, aes_string(xvar, yvar, color = "selected_")) +
        geom_point(alpha = 0.6) +
        scale_color_manual(values = c("black", "green")) +
        guides(color = FALSE) +
        xlab(xvar) + ylab(yvar)
    })
    insertUI("#plot_container", where = "beforeEnd",
      ui = div(style = css(display = "inline-block"),
        plotOutput(id, brush = "brush", width = 275, height = 275)
      )
    )
  })
  
  # Whenever the dataset changes, clear all plots
  observeEvent(dataset(), {
    removeUI("#plot_container *")
  })
}

shinyApp(ui, server)
