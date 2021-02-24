classdef MySpringShiftFit < MyFitParamScaling
    
    methods (Access = public)
        function this = MySpringShiftFit(varargin)
            this@MyFitParamScaling( ...
                'fit_name',         'Optomechanical spring shift', ...
                'fit_function',     'e*4*(x-c)*b/2/((x-c)^2+(b/2)^2)^2 + 1/pi*a*b/2/((x-c)^2+(b/2)^2)+d', ...
                'fit_tex',          '$$e\frac{4(x-c)b/2}{((x-c)^2+(b/2)^2)^2} + \frac{a}{\pi}\frac{b/2}{(x-c)^2+(b/2)^2}+d$$', ...
                'fit_params',       {'a','b','c','d','e'}, ...
                'fit_param_names',  {'Absorption amplitude','Width','Center','Offset', 'OM shift amplitude'}, ...
                varargin{:});
        end
    end
    
    methods (Access = protected)
        
        function calcInitParams(this)
            ind = this.data_selection;
            
            x = this.Data.x(ind);
            y = this.Data.y(ind);

            this.lim_upper=[Inf,Inf,Inf,Inf,Inf];
            this.lim_lower=[-Inf,0,-Inf,-Inf,0];

            % Finds peaks on the positive signal (max 1 peak)
            rng_x = max(x)-min(x);
            try
<<<<<<< Updated upstream
                [~, locs(1), widths(1), proms(1)] = findpeaks(y, x,...
=======
                [max_val, max_loc, max_width, max_prom] = findpeaks(y, x,...
>>>>>>> Stashed changes
                    'MinPeakDistance', rng_x/2, 'SortStr', 'descend',...
                    'NPeaks', 1);
            catch ME
                warning(ME.message)

<<<<<<< Updated upstream
                proms(1) = 0;
=======
               max_prom = 0;
>>>>>>> Stashed changes
            end

            % Finds peaks on the negative signal (max 1 peak)
            try
<<<<<<< Updated upstream
                [~,locs(2),widths(2),proms(2)] = findpeaks(-y, x,...
=======
                [min_val, min_loc, min_width, min_prom] = findpeaks(-y, x,...
>>>>>>> Stashed changes
                    'MinPeakDistance', rng_x/2, 'SortStr', 'descend',...
                    'NPeaks', 1);
            catch ME
                warning(ME.message)
<<<<<<< Updated upstream
                
                proms(2) = 0;
            end

            if proms(1)==0 && proms(2)==0
                warning(['No peaks were found in the data, giving ' ...
                    'default initial parameters to fit function'])
                
                this.param_vals = [1,1,1,1];
                this.lim_lower = -[Inf,0,Inf,Inf];
                this.lim_upper = [Inf,Inf,Inf,Inf];
                return
            end

            %If the prominence of the peak in the positive signal is 
            %greater, we adapt our limits and parameters accordingly, 
            %if negative signal has a greater prominence, we use this 
            %for fitting.
            if proms(1)>proms(2)
                ind=1;
                p_in(4)=min(y);
            else
                ind=2;
                p_in(4)=max(y);
                proms(2)=-proms(2);
            end

            p_in(2)=widths(ind);
            
            %Calculates the amplitude, as when x=c, the amplitude 
            %is 2a/(pi*b)
            p_in(1)=proms(ind)*pi*p_in(2)/2;
            p_in(3)=locs(ind);

=======

               min_prom = 0;
            end

            if min_prom==0 && max_prom==0
                warning(['No peaks were found in the data, giving ' ...
                    'default initial parameters to fit function'])
                return
            end
            % Width
            p_in(2) = abs(min_loc-max_loc)*sqrt(3);
            
            % OM Amplitude
            p_in(5) = abs(max_val - min_val)*p_in(2)^2/sqrt(3);
            
            % Center
            p_in(3) = (min_loc+max_loc)/2;
            
            % Offset
            p_in(4) = mean(y);
            
            % Absorption amplitude
            p_in(1) = -abs(abs(max_val - p_in(4)) - abs(min_val - p_in(4)))*pi*p_in(2)/2;
            
            
>>>>>>> Stashed changes
            this.param_vals = p_in;
            this.lim_lower(2)=0.01*p_in(2);
            this.lim_upper(2)=100*p_in(2);
        end
        
        function genSliderVecs(this)
            genSliderVecs@MyFit(this);
            
            try 
                
                %We choose to have the slider go over the range of
                %the x-values of the plot for the center of the
                %Lorentzian.
                this.slider_vecs{3}=...
                    linspace(this.Fit.x(1),this.Fit.x(end),101);
                %Find the index closest to the init parameter
                [~,ind]=...
                    min(abs(this.param_vals(3)-this.slider_vecs{3}));
                %Set to ind-1 as the slider goes from 0 to 100
                set(this.Gui.(sprintf('Slider_%s',...
                    this.fit_params{3})),'Value',ind-1);
            catch 
            end
        end
    end
    
    methods (Access = protected)
        function sc_vals = scaleFitParams(~, vals, scaling_coeffs)
            [mean_x,std_x,mean_y,std_y]=scaling_coeffs{:};
            
            sc_vals(1)=vals(1)/(std_y*std_x);
            sc_vals(2)=vals(2)/std_x;
            sc_vals(3)=(vals(3)-mean_x)/std_x;
            sc_vals(4)=(vals(4)-mean_y)/std_y;
            sc_vals(5)=vals(5) / std_y / std_x^2;
        end
        
        %Converts scaled coefficients to real coefficients
        function vals = unscaleFitParams(~, sc_vals, scaling_coeffs)
            [mean_x,std_x,mean_y,std_y]=scaling_coeffs{:};
            
            vals(1)=sc_vals(1)*std_y*std_x;
            vals(2)=sc_vals(2)*std_x;
            vals(3)=sc_vals(3)*std_x+mean_x;
            vals(4)=sc_vals(4)*std_y+mean_y;
            vals(5)=sc_vals(5) * std_y * std_x^2;
        end
    end
end