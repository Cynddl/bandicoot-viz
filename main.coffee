class Timeline
    constructor: (data, domains, bin_spacing=50, bin_width=10) ->
        @bin_spacing = bin_spacing
        @bin_width = bin_width
        @domains = domains

        @dom = null

        @timeAxis_padding = 20

        @data = data
        [first_data, ..., last_data] = data

        @first_week = new Date(first_data.key)
        @last_week  = new Date(last_data.key)        

        # Time scale
        @time = d3.time.scale()
            .domain([@first_week, @last_week])
            .range([0, @bin_spacing * @data.length])

        # Vertical scale
        @y = d3.scale.linear()
            .domain([0, d3.max(@data, (d) -> d.values)])
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
            .data(@data)
            .enter().append("g")
            .attr("class", "bar")
            .attr("transform", (d) => "translate(" + @time(new Date(d.key)) + "," + @y(d.values) + ")")

        @bar.append("rect")
            .attr("x", - @bin_width / 2)
            .attr("width", @bin_width)
            .attr("height", (d) => @domains[1][0] - @timeAxis_padding - @y(d.values))

    selectWeek: (id, duration=200) ->
        @dom.selectAll('.bar')
            .attr("class", (d, i) -> if i == id then "bar selected" else "bar")

        @dom
            .transition()
            .ease("sin")
            .duration(duration)
            .attr("transform", "translate(" + (width / 2 - @time(new Date(@data[id].key))) + ", 0)")



class BubbleGraph
    constructor: (events, domains, selected_week) ->
        @domains = domains
        @width = @domains[0][1] - @domains[0][0]
        @height = @domains[1][1] - @domains[1][0]

        @selected_week = selected_week

        @events = events

        @ego = d3.nest()
            .key((d) -> if d.sender == "me" then d.receiver else d.sender)
            .entries(@events)

        weekly_nest = d3.nest()
            .key((d) -> d3.time.week(d.date))

        @ego.forEach((d) ->
            d.week_groups = weekly_nest.map(d.values, d3.map)
            d.radius = d.week_groups.get(@selected_week)?.length)


        @bubble = d3.layout.pack()
            .value((d) -> d.week_groups.get(@selected_week)?.length)
            .sort(null)
            .padding(50)
            .radius((d) -> d)
            .size([500, 500])

        @bubbleNodes = @bubble.nodes( children: @ego )

        @force = d3.layout.force()
            .nodes(@bubbleNodes)
            .size([500, 500])
            .charge((d) -> if d.radius then -Math.pow(d.radius, 0.5) * 30 else 0)
            .on("tick", @tick)

        @egoChart = null


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
            .attr("r", (d) -> if d.radius then 5*Math.log(d.radius))
            .attr("opacity", 0.4)
            .style("fill", (d) -> d.key && fill(d.key) || "none" )

        @egoTitles = @egoChart.append("text")
            .attr("text-anchor", "left")
            .attr("dy", ".3em")
            .text((d) -> if (d.key && d.r > 0) then d.key.substring(0, 10))

        @force.start()


    tick: =>
        @egoChart
            .data(@bubbleNodes)
            .attr("transform", (d) -> "translate(" + d.x + "," + d.y + ")")


    selectWeek: (selected_week) ->
        @selected_week = selected_week
        @force.nodes().forEach((d) =>
            d.radius = d.week_groups?.get(@selected_week)?.length
            d.r = if d.radius then 5*Math.log(d.radius) else undefined
        )

        @force
            .charge((d) -> if d.radius then -Math.pow(d.radius, 0.5) * 50 else 0)
            .start()

        @egoCircles
            .transition()
            .duration(200)
            .attr("r", (d) -> d.r)

        # Display texts if radius is not zero
        @egoTitles
            .text((d) -> if (d.key && d.r > 0) then d.key.substring(0, 10))

    unique_contacts: () ->
        return @force.nodes()
            .filter((d) -> d.radius?)
            .length

    interactions: () ->
        list_interactions = @force.nodes()
            .map((d) -> d.radius)
        return d3.sum(list_interactions)
            



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
svg = d3.select("body").append("svg")
    .attr("width", width)
    .attr("height", height)

# Header



hist_height = 100
bin_width = 10
margin = left: 10, right: 10, bottom: 10, top: 10


# Load (random) data
#d3.json "data/random.json", (data) ->
#    events = data.events

#d3.csv "data/daily_calls_ID_conv.csv", (events) ->
d3.csv "data/daily_SMS_log.csv", (events) ->

    #me = "37349f07c95879abf625e8e7ae56170c"
    me = "FA10-01-05"

    events = events.filter((d) -> d.caller_id == me or d.callee_id == me)

    events.forEach((d) ->
        d.date = new Date(d.date)
        if d.caller_id == me
            d.sender = "me"
            d.receiver = d.callee_id
        else
            d.sender = d.caller_id
            d.receiver = "me"
    )


    events = events.sort((d) -> d.date)
    nested_data = d3.nest()
        .key((d) -> new Date(d3.time.week(d.date)))
        .sortKeys((a, b) -> new Date(a).valueOf() - new Date(b).valueOf())
        .rollup((a) -> d3.sum(a, (d) -> 1))
        .entries(events)

    ## Timeline at the bottom of the window
    timeline = new Timeline nested_data, [[0, width], [height, height - 100]]
    timeline.render svg

    selected_week_id = nested_data.length // 2
    selected_week = new Date(nested_data[selected_week_id].key)
    timeline.selectWeek selected_week_id


    ## Ego network
    fill = d3.scale.category20c()
    ego_graph = new BubbleGraph events, [[50, 550], [50, 550]], selected_week
    ego_graph.render svg, fill
    

    ## Captions
    unique_contacts = ego_graph.unique_contacts()
    nb_contacts = new Caption "Number of contacts", unique_contacts, [[600, 900], [250, 300]]
    nb_contacts.render svg

    nb_interactions = new Caption "Number of interactions", ego_graph.interactions(), [[600, 900], [300, 350]]
    nb_interactions.render svg

    week_format = (w) -> 
        d3.time.format("%a. %d")(w) + " - " + d3.time.format("%a. %d (%b. %Y)")(d3.time.monday(w))

    week_caption = new Caption "week", week_format(selected_week), [[600, 900], [50, 100]]
    week_caption.render svg
    


    ## Histograms
    inter_events_week = (events, week) ->
        events_week = events
            .filter((d) -> d3.time.week(d.date).valueOf() == selected_week.valueOf())
            .sort((a, b) -> a.date.valueOf() - b.date.valueOf())

        inter_events = events_week
            .map((d, i) ->
                (d.date.valueOf() - events_week[i-1]?.date.valueOf()) / 1000)
            .filter((d) -> d > 0)
            .sort(d3.ascending)
        
        return inter_events

    # Histograms
    inter_events = inter_events_week events, selected_week
    hist_1 = new Histogram inter_events, [[600, 900], [100, 150]]
    hist_1.render svg, "Inter-events", "interevents"

    # random_values = d3.range(1000).map(d3.random.bates(1))
    # hist_2 = new Histogram random_values, [[600, 900], [250, 300]]
    # hist_2.render svg, "Diversity", "diversity"


    ## Update
    d3.select('body').on("keydown", () ->
        key = d3.event.keyCode

        if key == 37 and selected_week_id > 0
            selected_week_id -= 1
        else if key == 39 and selected_week_id < nested_data.length - 1
            selected_week_id += 1

        selected_week = new Date(nested_data[selected_week_id].key)
        
        timeline.selectWeek selected_week_id
        ego_graph.selectWeek selected_week


        # Update inter-events
        inter_events = inter_events_week(events, selected_week)
        hist_1.update inter_events

        # Update captions
        nb_contacts.update ego_graph.unique_contacts()
        nb_interactions.update ego_graph.interactions()
    )
