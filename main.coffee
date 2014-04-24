class Timeline
    constructor: (data, domains, bin_spacing=50, bin_width=10) ->
        @bin_spacing = bin_spacing
        @bin_width = bin_width
        @domains = domains

        @dom = null

        @timeAxis_padding = 20

        @data = data
        @data_keys = @data.keys().sort(d3.ascending)
        [first_data, ..., last_data] = @data_keys


        @first_week = new Date(first_data)
        @last_week  = new Date(last_data)        

        # Time scale
        @time = d3.time.scale()
            .domain([@first_week, @last_week])
            .range([0, @bin_spacing * @data_keys.length])

        # Vertical scale
        @y = d3.scale.linear()
            .domain([0, d3.max(@data.values(), (d) -> d.number_of_interactions)])
            .range([@domains[1][0] - @timeAxis_padding, @domains[1][1]])

        @timeAxis = d3.svg.axis()
            .scale(@time)
            .orient("bottom")
            .ticks(d3.time.weeks)
            .tickFormat(d3.time.format("%a %d"))

    render: (svg, id='#timeline') ->
        @dom = svg.append("g")
            .attr("id", id)
            .attr("class", "timeline")

        @dom.append("g")
            .attr("class", "time axis")
            .attr("transform", "translate(0," + (@domains[1][0] - @timeAxis_padding) + ")")
            .call(@timeAxis)

        # Render bars
        @bar = @dom.selectAll(".bar")
            .data(@data.entries())
            .enter().append("g")
            .attr("class", "bar")
            .attr("transform", (d) => "translate(" + @time(new Date(d.key)) + "," + @y(d.value.number_of_interactions) + ")")

        @bar.append("rect")
            .attr("x", - @bin_width / 2)
            .attr("width", @bin_width)
            .attr("height", (d) => @domains[1][0] - @timeAxis_padding - @y(d.value.number_of_interactions))

    selectWeek: (id, duration=200) ->
        key = @data_keys[id]
        datum = new Date(key)

        @dom.selectAll('.bar')
            .attr("class", (d) -> if key == d.key then "bar selected" else "bar")

        @dom
            .transition()
            .ease("sin")
            .duration(duration)
            .attr("transform", "translate(" + (width / 2 - @time(datum)) + ", 0)")



class BubbleGraph
    constructor: (events, domains, selected_week_id) ->
        @domains = domains
        @width = @domains[0][1] - @domains[0][0]
        @height = @domains[1][1] - @domains[1][0]

        @events = events
        @events_keys = @events.keys()

        @selected_week_id = selected_week_id
        @selected_week_key = @events_keys[selected_week_id]
        

        @ego = d3.map(@events.get(@selected_week_key).events).entries()

        @bubble = d3.layout.pack()
            .sort(null)
            .padding(50)
            .radius((d) -> d)
            .size([500, 500])

        @bubbleNodes = @bubble.nodes( children: @ego )

        @force = d3.layout.force()
            .nodes(@bubbleNodes.filter((d) -> !d.children))
            .size([500, 500])
            .on("tick", @tick)


    render: (svg, fill, id='#bubble') ->
        @dom = svg.append("g")
            .attr("id", id)
            .attr("class", "timeline")

        @egoChart = @dom.selectAll(".ego")
            .data(@bubbleNodes)
            .enter().append("g")
            .attr("class", "ego")
            .attr("transform", (d) -> "translate(" + d.x + "," + d.y + ")")

        @egoCircles = @egoChart.append("circle")
            .attr("opacity", 0.4)
            .style("fill", (d) -> d.key && fill(d.key) || "none" )

        @egoTitles = @egoChart.append("text")
            .attr("text-anchor", "left")
            .attr("dy", ".3em")
            .attr("dx", ".8em")

        # Update graph
        this.selectWeek @selected_week_id


    tick: =>
        @egoChart
            .data(@bubbleNodes)
            .attr("transform", (d) -> "translate(" + d.x + "," + d.y + ")")


    selectWeek: (selected_week_id) ->
        @selected_week_id = selected_week_id
        @selected_week_key = @events_keys[@selected_week_id]

        weekly_events = @events.get(@selected_week_key).events

        @force.nodes().forEach (d) ->
            d.value = weekly_events[d.key]
            d.r = d.value

        @force
            .charge((d) -> -d.r * 50)
            .start()

        @egoCircles
            .transition()
            .duration(200)
            .attr("r", (d) -> d.r * 5)

        # Display texts if radius is not zero
        @egoTitles
            .transition()
            .duration(200)
            .attr("opacity", (d) -> if d.key && d.r > 0 then 1 else 0)
            .text((d) -> if d.key && d.r > 0 then d.key.substring(0, 10))


class Histogram
    constructor: (data, domains) ->
        @domains = domains
        @width = @domains[0][1] - @domains[0][0]
        @height = @domains[1][1] - @domains[1][0]

        # Horizontal scale
        @x = d3.scale.linear()
            .domain(data)
            .range(@domains[0])

        @data = d3.layout.histogram()
            .bins(10) (data)

        # Vertical scale
        @y = d3.scale.linear()
            .domain(d3.extent(@data, (d) -> d.y))
            .range([d3.max(domains[1]), d3.min(domains[1])])


        # Bottom axis
        @xAxis = d3.svg.axis()
            .scale(@x)
            .ticks(3, ",.1s")
            .orient("bottom")

        @points = null

    update: (data) ->
        @x.domain(d3.extent(data))

        @data = d3.layout.histogram()
            .bins(10) (data)

        @y.domain(d3.extent(@data, (d) -> d.y))

        @path.datum(@data)
            .attr("d", @line)

        @points
            .data(@data)
            .attr("cx", (d) => @x(d.x))
            .attr("cy", (d) => @y(d.y))

        @axis
            .call(@xAxis)




    render : (svg, title='Truc', id='histogram') ->
        @dom = svg.append("g")
            .attr("class", "histogram")
            .attr("id", id)

        @dom.append("text")
            .attr("class", "title")
            .attr("transform", "translate(#{@domains[0][0]}, #{@domains[1][0]})")
            .text(title)

        # @dom.append("rect")
        #     .attr("class", "background")
        #     .attr("width", @width + 10)
        #     .attr("height", @height + 10)
        #     .attr("x", @x(0) - 5)
        #     .attr("y", @domains[1][0] - 5)

        @line = d3.svg.line()
            .interpolate("basis")
            .x((d) => @x(d.x))
            .y((d) => @y(d.y))

        @path = @dom.append("path")
            .datum(@data)
            .attr("class", "line")
            .attr("d", @line)

        @points = @dom.selectAll(".point")
            .data(@data)
            .enter().append("circle")
            .attr("class", "dot")
            .attr("cx", (d) => @x(d.x))
            .attr("cy", (d) => @y(d.y))
            .attr("r", 3)

        @axis = @dom.append("g")
            .attr("class", "axis")
            .attr("transform", "translate(0, #{@domains[1][1]})")
            .call(@xAxis)

        repeat = () =>
            @points
                .transition()
                .duration(500)
                .style("opacity", (d) -> Math.random() * 0.8 + 0.2)
                .each("end", repeat)
        repeat()


class Caption
    constructor: (label_msg, text_msg, domains) ->
        @label_msg = label_msg
        @text_msg = text_msg
        @domains = domains

    render : (svg, id='caption') ->
        @dom = svg.append("g")
            .attr('id', id)
            .attr('class', 'caption')
            .attr("transform", "translate(#{@domains[0][0]}, #{@domains[1][0]})")

        @label = @dom
            .append("text")
            .text(@label_msg)
            .attr("class", "title")

        @text = @dom
            .append("text")
            .text(@text_msg)
            .attr("class", "text")
            .attr("transform", "translate(0, 20)")

    update: (text_msg) ->
        @text_msg = text_msg
        @text
            .text(@text_msg)



dimension_window = () ->
    w = window
    d = document
    e = d.documentElement
    g = d.getElementsByTagName('body')[0]
    x = w.innerWidth || e.clientWidth || g.clientWidth
    y = w.innerHeight|| e.clientHeight|| g.clientHeight

    return [x, y]


# SVG element (full-size)
[width, height] = dimension_window()
width = width * 0.7 # Left panel

svg = d3.select("body").append("svg")
    .attr("width", width)
    .attr("height", height)


# URL parameters
getParams = ->
  query = window.location.search.substring(1)
  raw_vars = query.split("&")
  params = {}

  for v in raw_vars
    [key, val] = v.split("=")
    params[key] = decodeURIComponent(val)

  params

params = getParams()
pin = params['pin']



# Load metadata
d3.json "http://socialmetadata.linkedpersonaldata.org/bandicoot/pin/#{pin}/", (events) ->

    events = d3.map(events)

    events_keys = events.keys().sort(d3.ascending)

    me = "37349f07c95879abf625e8e7ae56170c"

    ## Timeline at the bottom of the window
    timeline = new Timeline events, [[0, width], [height, height - 100]]
    timeline.render svg

    selected_week_id = events_keys.length // 2
    selected_week = events_keys[selected_week_id]
    timeline.selectWeek selected_week_id


    ## Ego network
    fill = d3.scale.category20c()
    ego_graph = new BubbleGraph events, [[50, 550], [50, 550]], selected_week_id
    ego_graph.render svg, fill
    

    weekly = events.get(selected_week)

    ## Captions
    caption_entropy = new Caption "Entropy", weekly.entropy, [[700, 900], [250, 300]]
    caption_entropy.render svg

    nb_interactions = new Caption "Number of interactions", weekly.number_of_interactions, [[700, 900], [300, 350]]
    nb_interactions.render svg

    percent_initiated = new Caption "% initiated", d3.format("%")(weekly.percent_initiated), [[700, 900], [350, 400]]
    percent_initiated.render svg

    week_format = (w) -> 
        d3.time.format("%a. %d (%b. %Y)")(d3.time.monday(w))

    week_caption = new Caption "week", week_format(new Date(selected_week)), [[700, 900], [50, 100]]
    week_caption.render svg
    


    # ## Histograms
    # inter_events_week = (events, week) ->
    #     events_week = events
    #         .filter((d) -> d3.time.week(d.date).valueOf() == selected_week.valueOf())
    #         .sort((a, b) -> a.date.valueOf() - b.date.valueOf())

    #     inter_events = events_week
    #         .map((d, i) ->
    #             (d.date.valueOf() - events_week[i-1]?.date.valueOf()) / 1000)
    #         .filter((d) -> d > 0)
    #         .sort(d3.ascending)
        
    #     return inter_events

    # # Histograms
    # inter_events = inter_events_week events, selected_week
    # hist_1 = new Histogram inter_events, [[700, 900], [100, 150]]
    # hist_1.render svg, "Inter-events", "interevents"

    # # random_values = d3.range(1000).map(d3.random.bates(1))
    # # hist_2 = new Histogram random_values, [[700, 900], [250, 300]]
    # # hist_2.render svg, "Diversity", "diversity"


    ## Update
    d3.select('body').on("keydown", () ->
        key = d3.event.keyCode

        if key == 37 and selected_week_id > 0
            selected_week_id -= 1
        else if key == 39 and selected_week_id < events_keys.length - 1
            selected_week_id += 1

        selected_week = events_keys[selected_week_id]
        timeline.selectWeek selected_week_id
        ego_graph.selectWeek selected_week_id


        # Update inter-events
        # inter_events = inter_events_week(events, selected_week)
        # hist_1.update inter_events

        # Update captions
        weekly = events.get(selected_week)
        caption_entropy.update weekly.entropy
        nb_interactions.update weekly.number_of_interactions
        week_caption.update week_format(new Date(selected_week))
        percent_initiated.update d3.format("%")(weekly.percent_initiated)
    )
