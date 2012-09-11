@include = ->


  ############# break and split ###############

  @view breaknsplit : ->


    style '@import url("css/charts/time-series.css");'
    style '@import url("css/breaknsplit.css");'
    script src: 'coffee/charts/time-series.js'
    script src: 'coffee/utils-aiddata.js'
    script src: 'coffee/utils.js'
    script src: 'queue.js'
    script src: 'breaknsplit.js'

    div id:"loading", -> "Loading..."
    div id:"error"
    div id:"content", ->



      div id:"outerTop", ->

        div class:"row-fluid", ->

          div class:"span6", ->
            div id:"tseries", class:"tseries"

    

          div class:"span6", ->

            div class:"row-fluid", ->
              div class:"span2 prophdr", ->
                div "Donors"
              div class:"span2 prophdr", ->
                div "Recipients"
              div class:"span2 prophdr", ->
                div "Purposes"

            div class:"row-fluid", ->              
              div class:"span2 bnsctl", ->
                button class:"btn btn-mini","data-toggle":"dropdown", -> "Break&nbsp;down"
              div class:"span2 bnsctl", ->
                button class:"btn btn-mini","data-toggle":"dropdown", -> "Break&nbsp;down"
              div class:"span2 bnsctl", ->
                button class:"btn btn-mini","data-toggle":"dropdown", -> "Break&nbsp;down"



  @coffee '/breaknsplit.js': ->

    queue()
      .defer(loadCsv, "dv/flows/breaknsplit.csv?breakby=date")
      .defer(loadJson, "purposes.json")
      .await (err, data) ->
        console.log data
        unless data?
          $("#loading").remove()
          $("#error")
            .addClass("alert-error alert")
            .html("Could not load flow data")
          return

        [ flows, purposes ] = data

        tschart = timeSeriesChart()
          .width(500)
          .height(300)
          .title("AidData: Total commitment amount by year")
          .valueTickFormat(shortMagnitudeFormat)

        datum = []

        minDate = d3.time.format("%Y").parse("1942")
        maxDate = Date.now()

        for d in flows

          date = utils.date.yearToDate(d.date)
          if date?  and  (minDate <= date <= maxDate)
            datum.push
              date : date
              outbound : +d.sum_amount_usd_constant


        d3.select("#tseries").datum(datum).call(tschart)

        


        $("#loading").remove()
        $("#content").show()





  
  ############# bubbles ###############

  @view bubbles: ->
    @page = "bubbles"
    @dataset = "aiddata"

    style '@import url("css/charts/bar-hierarchy.css");'
    style '@import url("css/charts/time-series.css");'
    style '@import url("css/charts/time-slider.css");'

    style '@import url("css/charts/bubbles.css");'
    style '@import url("css/bubbles.css");'

    div id:"loading", -> "Loading..."
    div id:"bubblesChart"


    ###
    div id: "yearSliderOuter", ->

      div id:"play", class:"ui-state-default ui-corner-all", ->
          span class:"ui-icon ui-icon-play"

      div id:'yearSliderInner', ->
        div id:'yearSlider'
        div id:'yearTicks'
    ###

    div id:"tseriesPanel"

    div id:"purposeBars"

    div id:"timeSlider"

    style '@import url("libs/tipsy-new/stylesheets/tipsy.css");'
    script src: "libs/tipsy-new/javascripts/jquery.tipsy.js"

    script src: 'js/fit-projection.js'
    script src: 'coffee/utils.js'
    script src: 'coffee/utils-aiddata.js'
    #script src: "coffee/time-slider.js"
    script src: "coffee/charts/bubbles.js"
    script src: "coffee/charts/bar-hierarchy.js"
    script src: "coffee/charts/time-series.js"
    script src: "coffee/charts/time-slider.js"
    script src: "bubbles.js"



  @coffee '/bubbles.js': ->

    years = [1947..2011]
    startYear = 2007

    # Bubbles
    bubbles = bubblesChart()
      .conf(
        flowOriginAttr: 'donor'
        flowDestAttr: 'recipient'
        nodeIdAttr: 'code'
        nodeLabelAttr: 'name'
        latAttr: 'Lat'
        lonAttr: 'Lon'
        flowMagnAttrs: years
        )
      .on "changeSelDate", (current, old) -> timeSlider.setTime(current)


    barHierarchy = barHierarchyChart()
      .width(400)
      .barHeight(10)
      .labelsWidth(200)
      .childrenAttr("values")
      .nameAttr("name")
      .valueFormat(formatMagnitude)
      .values((d) -> d["sum_#{startYear}"] ? 0)
      # .values((d) -> d.totals[startYear].sum ? 0)
      #.values((d) -> d.totals["sum_#{startYear}"] ? 0)
      .labelsFormat((d) -> shorten(d.name ? d.key, 35))
      .labelsTooltipFormat((d) -> name = d.name ? d.key)
      .breadcrumbText(
        do ->
          percentageFormat = d3.format(",.2%")
          (currentNode) ->
            v = barHierarchy.values()
            data = currentNode; (data = data.parent while data.parent?)
            formatMagnitude(v(currentNode)) + " (" + 
            percentageFormat(v(currentNode) / v(data)) + " of total)"
      )


    groupFlowsByOD = (flowList) -> 
      nested = d3.nest()
        .key((d) -> d.donor)
        .key((d) -> d.recipient)
        .key((d) -> d.date)
        .entries(flowList)

      flows = []
      for o in nested
        for d in o.values
          entry =
            donor : o.key
            recipient : d.key

          for val in d.values
            entry[val.key] = val.values[0].sum_amount_usd_constant

          flows.push entry
      flows


    timeSlider = timeSliderControl()
      .min(utils.date.yearToDate(years[0]))
      .max(utils.date.yearToDate(years[years.length - 1]))
      .step(d3.time.year)
      .format(d3.time.format("%Y"))
      .width(250 - 30 - 8) # timeSeries margins
      .height(10)
      .on "change", (current, old) ->
        bubbles.setSelDateTo(current, true)
        barHierarchy.values((d) -> d["sum_" + utils.date.dateToYear(current)] ? 0)

    loadData()
      .csv('nodes', "#{dynamicDataPath}aiddata-nodes.csv")
      #.csv('flows', "#{dynamicDataPath}aiddata-totals-d-r-y.csv")
      .csv('flows', "dv/flows/by/od.csv")
      .json('map', "data/world-countries.json")
      .csv('countries', "data/aiddata-countries.csv")
      .csv('flowsByPurpose', "dv/flows/by/purpose.csv")
      .json('purposeTree', "purposes-with-totals.json")
      .onload (data) ->


        # list of flows with every year separated
        #   -> list grouped by o/d, all years' values in one object
        data.flows = groupFlowsByOD data.flows 

        provideCountryNodesWithCoords(
          data.nodes, { code: 'code', lat: 'Lat', lon: 'Lon'},
          data.countries, { code: "Code", lat: "Lat", lon: "Lon" }
        )

        d3.select("#bubblesChart")
          .datum(data)
          .call(bubbles)


        d3.select("#timeSlider")
          .call(timeSlider)

        # purposes = d3.nest()
        #   .key((d) -> d.date)
        #   .map(data.purposes)

        valueAttrs = do ->
          arr = []
          for y in years
            for attr in ["sum", "count"]
              arr.push "#{attr}_#{y}"
          arr

        utils.aiddata.purposes.provideWithTotals(data.purposeTree, valueAttrs, "values", "totals")

        d3.select("#purposeBars")
          .datum(data.purposeTree) #utils.aiddata.purposes.fromCsv(purposes['2007']))
          .call(barHierarchy)

        bubbles.setSelDateTo(utils.date.yearToDate(startYear), true)

        $("#loading").remove()
  












  ############# horizon ###############


  @view horizon: ->
    @page = "horizon"
    
    div id:'horizonParent', ->
      div id:'originsChart',class:'horizonChart'
      div id:'destsChart',class:'horizonChart'

    style '@import url("css/horizon.css");'
    script src: 'queue.min.js'
    script src: 'js/cubism.v1.my.js'
    script src: 'coffee/utils.js'
    #script src: 'js/cubism-aiddata.js'
    script src: 'libs/chroma/chroma.min.js'
    script src: 'libs/chroma/chroma.colors.js'
    script src: 'coffee/horizon-aiddata.js'





  ############# ffprints ###############

  @view ffprints: ->
    @page = "ffprints"
    @dataset = "aiddata"

    style '@import url("css/ffprints.css");'
    div id:"radioset", style:"display:inline-block", ->
      
      span style:"margin-right:10px","Positioning:"

      input name:"nodePositioningMode", id:"useGeoNodePositions", type:"radio", checked:"checked"
      label "for":"useGeoNodePositions", -> "Geo"

      input name:"nodePositioningMode", id:"useForce", type:"radio"
      label "for":"useForce", -> "Pack"

      input name:"nodePositioningMode", id:"useGrid", type:"radio", disabled:"disabled"
      label "for":"useGrid", style:"margin-left:5px", -> "Grid"

      input name:"nodePositioningMode", id:"useAligned", type:"radio", disabled:"disabled"
      label "for":"useAligned", style:"margin-left:5px", -> "Align"

    #div id:'slider', style:'width:300px;display:inline-block; margin-left:20px; margin-top:7px;'
    div id: 'loading', style:'margin-top:20px', -> "Loading view..."
    div id: 'ffprints', style:'margin-top:20px'

    style '@import url("libs/tipsy-new/stylesheets/tipsy.css");'
    script src: "libs/tipsy-new/javascripts/jquery.tipsy.js"

    script src: 'libs/chroma/chroma.min.js'
    script src: 'libs/chroma/chroma.colors.js'
    script src: 'js/fit-projection.js'
    script src: 'coffee/ffprints.js'
    script src: 'coffee/utils.js'

    script src: "coffee/ffprints-#{@dataset}.js"
    






  ############# crossfilter ###############

  @view crossfilter: ->
    @page = "crossfilter"
    @dataset = "aiddata"
    #script src: 'coffee/utils.js'

    style '@import url("css/crossfilter.css");'


    div id: "charts", ->

      
      div id: "year-chart", class: "chart", ->
        div class: "title", -> "Num of commitments by Year"

      div id: "amount-chart", class: "chart", ->
        div class: "title", -> "Commitment amounts"
    
      aside id:"totals", ->
        span id:"active", -> "-"
        span " of "
        span id:"total", -> "-"
        " commitments selected."

      div id:"lists", ->
        div id:"flow-list", class:"list"


    script src: 'crossfilter.js'
    script src: 'underscore.js'
    script src: 'coffee/utils-aiddata.js'
    script src: 'coffee/crossfilter-barchart.js'
    script src: 'coffee/crossfilter-aiddata.js'




  ############# purposeTree ###############

  @view purposeTree: ->
    @page = "purposeTree"

    style '@import url("css/purpose-tree.css");'
    div id:"purposeTree"

    script src: 'libs/chroma/chroma.min.js'
    script src: 'coffee/utils.js'
    script src: 'coffee/utils-aiddata.js'
    
    script src: "coffee/purpose-tree.js"




  ############# purposePack ###############

  @view purposePack: ->
    @page = "purposePack"

    style '@import url("css/purpose-pack.css");'
    div id:"purposePack"

    script src: 'coffee/utils.js'
    script src: 'coffee/utils-aiddata.js'
    
    script src: "coffee/purpose-pack.js"





  ############# purposeBars ###############

  @view purposeBars: ->
    @page = "purposeBars"

    style '@import url("css/charts/bar-hierarchy.css");'

    div id:"purposeBars"

    script src: 'coffee/utils.js'
    script src: 'coffee/utils-aiddata.js'
    
    script src: "coffee/charts/bar-hierarchy.js"
    script src: "purpose-bars.js"


  @coffee '/purpose-bars.js': ->
    $ ->
      percentageFormat = d3.format(",.2%")

      chart = barHierarchyChart()
        .width(550)
        .height(300)
        .childrenAttr("values")
        .valueAttr("amount")
        .nameAttr("key")
        .valueFormat(formatMagnitude)
        .breadcrumbText(
          (currentNode) ->
            data = currentNode; (data = data.parent) while data.parent?
            formatMagnitude(currentNode.amount) + " (" + 
            percentageFormat(currentNode.amount / data.amount) + " of total)"
        )


      d3.csv "aiddata-purposes-with-totals.csv/2007", (csv) ->
        d3.select("#purposeBars")
          .datum(utils.aiddata.purposes.fromCsv(csv))
          .call(chart)

    










  ############# US donations vs GDP ###############

  @view "us-donations": ->
    style '@import url("css/charts/time-series.css");'
    style '@import url("css/bubbles.css");'

    div id:"tseries2", class:"tseries", style:"margin-bottom:40px"
    div id:"tseries3", class:"tseries", style:"margin-bottom:40px"
    div id:"tseries1", class:"tseries", style:"margin-bottom:40px"

    script src: "coffee/charts/time-series.js"
    script src: 'coffee/utils.js'
    script src: 'coffee/utils-aiddata.js'
    script src: "us-donations.js"


  @coffee '/us-donations.js': ->
   $ ->
      tschart1 = timeSeriesChart()
        .width(800)
        .height(300)
        .marginLeft(200)
        #.title("Total US donations (blue, nominal US$) as percentage of US GDP (red, current US$)")
        .title("Total US foreign aid donations as percentage of US GDP")
        .valueTickFormat(d3.format(",.2%"))


      tschart2 = timeSeriesChart()
        .width(800)
        .height(300)
        .marginLeft(200)
        .title("US GDP (red, current US$), total US donations (blue, nominal US$)")
        .valueTickFormat(formatMagnitude)


      tschart3 = timeSeriesChart()
        .width(800)
        .height(300)
        .marginLeft(200)
        .title("Total US donations (blue, nominal US$)")
        .valueTickFormat(formatMagnitude)



      loadData()
        .json('gdp', "wb.json/NY.GDP.MKTP.CD/USA")
        #.json('donated', "aiddata-donor-totals.json/USA")
        .json('donated', "aiddata-donor-totals-nominal.json/USA")
        .onload (data) ->
          
          
          datum1 = []
          datum2 = []
          datum3 = []

          donated = {}
          donated[d.date] = d.sum_amount_usd_nominal  for d in data.donated

          for y, o of data.gdp
            year = utils.date.yearToDate(y)

            if (donated[y]?)
              datum1.push
                date : year
                outbound : +(donated[y]) / o.value 

            datum2.push
              date : year
              inbound : +o.value 
              outbound : +donated[y]

            datum3.push
              date : year
              outbound : +donated[y]


          d3.select("#tseries1")
            .datum(datum1).call(tschart1)
            .append("div")
              .attr("class", "credits")
              .attr("style", "font-size:10px; color:#ccc; text-align:center;")
              .text("Based on data from AidData.org and World Bank")

          d3.select("#tseries2").datum(datum2).call(tschart2)
          d3.select("#tseries3").datum(datum3).call(tschart3)





