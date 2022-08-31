module SciMLMakie

using Makie, SciMLBase

Makie.convert_arguments(P::Type{<:AbstractPlot}, x::SciMLBase.AbstractTimeseriesSolution) =  (x,)

@recipe(SolPlot, x, plot_type) do scene
	    Attributes(
			color=:darktest,
        	solid_color=nothing,
			labels = nothing,
			linestyle = :solid,
			transparency = nothing,
			linewidth = 1.5, 
			overdraw = false,
			#marker = nothing,
			markersize = 9,
			strokewidth = 0,
			strokecolor = :black,
			glowwidth = 0,
			rotations = 0
		)
end

function Makie.plot!(solplot::SolPlot)
	sol = solplot[:x].val
	if !(sol isa SciMLBase.AbstractTimeseriesSolution)
		throw("Input solution is not an AbstractTimeSeriesSolution")
	end
    
	# default values
    
	plotdensity = haskey(solplot, :plotdensity) ? solplot.plotdensity[] : (min(Int(1e5),sol.tslocation==0 ? (typeof(sol.prob) <: SciMLBase.AbstractDiscreteProblem ? max(1000,100*length(sol)) : max(1000,10*length(sol))) : 1000*sol.tslocation))
	
	plot_analytic = haskey(solplot, :plot_analytic) ? solplot.plot_analytic[] : false
	
    denseplot = haskey(solplot, :denseplot) ? solplot.denseplot[] : (sol.dense || typeof(sol.prob) <: SciMLBase.AbstractDiscreteProblem) && !(typeof(sol) <: SciMLBase.AbstractRODESolution) && !(hasfield(typeof(sol), :interp) && typeof(sol.interp) <: SciMLBase.SensitivityInterpolation)
	
	tspan = haskey(solplot, :tspan) ? solplot.tspan[] : nothing
	axis_safety = haskey(solplot, :axis_safety) ? solplot.axis_safety[] : 0.1
    vars = haskey(solplot, :vars) ? solplot.vars[] : nothing
			
	# Function implementation
	
	syms = SciMLBase.getsyms(sol)
    int_vars = SciMLBase.interpret_vars(vars, sol, syms)
    strs = SciMLBase.cleansyms(syms)
    tscale = get(solplot.attributes, :xscale, :identity)
    
    plot_vecs, labs = SciMLBase.diffeq_to_arrays(sol, plot_analytic, denseplot,
	                                         plotdensity, tspan, axis_safety,
	                                         vars, int_vars, tscale, strs)

	l = length(labs)
	labs = Observable(labs)

	@extract solplot (color, labels, solid_color, linestyle, transparency, linewidth, overdraw, markersize, strokewidth, strokecolor, glowwidth, rotations)
	colors = lift(color, solid_color) do color, scolor
        if isnothing(scolor)
            return categorical_colors(color, l)
        else
            return scolor
        end
  	end
	plot_type = try
		solplot[:plot_type].val		
	catch
	    @warn "Plot type not defined properly, using Lines as default"
		lines!
	end
	k = 0
	for i in 1:l
		#len = $colors isa AbstractVector ? length($colors) : 1
		label = @lift isnothing($labels) ? $labs[i] : $labels[i]
		series_color = @lift $colors isa AbstractVector && !($color isa Tuple) ? $colors[i] : $colors
		ls = @lift $linestyle isa AbstractVector ? $linestyle[i] : $linestyle
		transparent = @lift $transparency isa AbstractVector ? $transparency[i] : $transparency
		lw = @lift $linewidth isa AbstractVector ? $linewidth[i] : $linewidth
		od = @lift $overdraw isa AbstractVector ? $overdraw[i] : $overdraw
		ms = @lift $markersize isa AbstractVector ? $markersize[i] : $markersize
		sw = @lift $strokewidth isa AbstractVector ? $strokewidth[i] : $strokewidth
		sc = @lift $strokecolor isa AbstractVector ? $strokecolor[i] : $strokecolor
		gw = @lift $glowwidth isa AbstractVector ? $glowwidth[i] : $glowwidth
		rot = @lift $rotations isa AbstractVector ? $rotations[i] : $rotations

		if(vars != nothing)
			plot_type(solplot, hcat(plot_vecs...); color=series_color, label=label, linestyle = ls, transparency = transparent, linewidth = lw, overdraw = od, markersize = ms, strokewidth = sw, strokecolor = sc, glowwidth = gw, rotations = rot)
		else
			plot_type(solplot, plot_vecs[1][:,i], plot_vecs[2][:,i]; color=series_color, label=label, linestyle = ls, transparency = transparent, linewidth = lw, overdraw = od, markersize = ms, strokewidth = sw, strokecolor = sc, glowwidth = gw, rotations = rot)
		end
	end
end

function Makie.get_plots(plot::SolPlot)
   	return plot.plots
end

function esolplot(sol::SciMLBase.AbstractTimeseriesSolution, plot_type = lines!; kwargs...)
	vars = get(kwargs, :vars, nothing)
	if haskey(kwargs, :vars) && length(vars) > 3
		throw("length of vars can not be greater than 3")
	end
	a = haskey(kwargs, :vars) && length(vars) == 3 ? Axis3 : Axis
	println(a)
	f = Figure()
	ax = f[1, 1] = a(f)
	s = solplot!(sol, plot_type; kwargs...)
	f[1, 1] = Legend(f, ax, "Legend", tellwidth = false, halign = 1.0, valign = 1.0)
	f
end

export esolplot
end # module SciMLMakie
