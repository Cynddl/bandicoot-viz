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
            .range([@domains[1][0], @domains[1][1]])

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

        @events = events

        @ego = d3.nest()
            .key((d) -> if d.sender == "me" then d.receiver else d.sender)
            .entries(@events)

        weekly_nest = d3.nest()
            .key((d) -> d3.time.week(d.date))

        @ego.forEach((d) ->
            d.week_groups = weekly_nest.map(d.values, d3.map)
            d.radius = d.week_groups.get(selected_week)?.length)


        @bubble = d3.layout.pack()
            .value((d) -> d.week_groups.get(selected_week)?.length)
            .sort(null)
            .padding(50)
            .radius((d) -> d * 10)
            .size([500, 500])

        @bubbleNodes = @bubble.nodes( children: @ego )

        @force = d3.layout.force()
            .nodes(@bubbleNodes)
            .size([500, 500])
            .charge((d) -> if d.radius then -Math.pow(d.radius, 1) * 50 else 0)
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
            .attr("r", (d) -> d.r)
            .attr("opacity", 0.4)
            .style("fill", (d) -> d.key && fill(d.key) || "none" )

        @egoTitles = @egoChart.append("text")
            .attr("text-anchor", "left")
            .attr("dy", ".3em")
            .text((d) -> if (d.key && d.r > 0) then d.key.substring(0, 5))

        @force.start()


    tick: =>
        @egoChart
            .data(@bubbleNodes)
            .attr("transform", (d) -> "translate(" + d.x + "," + d.y + ")")


    selectWeek: (selected_week) ->
        @force.nodes().forEach((d) ->
            d.radius = d.week_groups?.get(selected_week)?.length
            d.r = d.radius? * 10
        )

        @force
            .charge((d) -> if d.radius then -Math.pow(d.radius, 1) * 50 else 0)
            .start()

        @egoCircles
            .transition()
            .duration(200)
            .attr("r", (d) -> d.r)

        # Display texts if radius is not zero
        @egoTitles
            .text((d) -> if (d.key && d.r > 0) then d.key.substring(0, 5))



class Histogram
    constructor: (data, domains) ->
        @domains = domains
        @width = @domains[0][1] - @domains[0][0]
        @height = @domains[1][1] - @domains[1][0]

        # Horizontal scale
        @x = d3.scale.linear()
            .domain([0, 1])
            .range(@domains[0])

        @data = d3.layout.histogram()
            .bins(@x.ticks(20)) (data)

        # Vertical scale
        @y = d3.scale.linear()
            .domain(d3.extent(@data, (d) -> d.y))
            .range([d3.max(domains[1]), d3.min(domains[1])])


        # Bottom axis
        @xAxis = d3.svg.axis()
            .scale(@x)
            .orient("bottom")

    render : (svg, title='Truc') ->
        @dom = svg.append("g")
            .attr("class", "histogram")

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

        line = d3.svg.line()
            .interpolate("basis")
            .x((d) => @x(d.x))
            .y((d) => @y(d.y))

        @dom.append("path")
            .datum(@data)
            .attr("class", "line")
            .attr("d", line)

        points = @dom.selectAll(".point")
            .data(@data)
            .enter().append("circle")
            .attr("class", "dot")
            .attr("cx", (d) => @x(d.x))
            .attr("cy", (d) => @y(d.y))
            .attr("r", 3)

        repeat = () ->
            points
                .transition()
                .duration(500)
                .style("opacity", (d) -> Math.random() * 0.8 + 0.2)
                .each("end", repeat)
        repeat()


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


hist_height = 100
bin_width = 10
margin = left: 10, right: 10, bottom: 10, top: 10


# Load (random) data
#d3.json "data/random.json", (data) ->
#    events = data.events

d3.csv "data/big_sample.csv", (events) ->

    me = "37349f07c95879abf625e8e7ae56170c"
    events.forEach((d) ->
        d.date = new Date(d.date)
        if d.caller_id == me
            d.sender = "me"
            d.receiver = d.callee_id
        else
            d.sender = d.caller_id
            d.receiver = "me"
        d.date = new Date(d.datetime)
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
    

    ## Histograms
    random_values = d3.range(1000).map(d3.random.bates(10))
    hist = new Histogram random_values, [[600, 900], [100, 150]]
    hist.render svg, "Inter-events"

    random_values = d3.range(1000).map(d3.random.bates(1))
    hist = new Histogram random_values, [[600, 900], [250, 300]]
    hist.render svg, "Diversity"


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
    )
