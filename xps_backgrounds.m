function [y_bkg, bkg_params] = xps_backgrounds(x, y, type, opts)
% XPS_BACKGROUNDS Calculates baseline for core-level spectra.
%   Types supported: 'linear', 'shirley', 'asls', 'tougaard'

if nargin < 4, opts = struct(); end

x = x(:); y = y(:);
N = length(x);

switch lower(type)
    case 'none'
        y_bkg = zeros(N, 1);
        bkg_params = struct('type', 'none');
        
    case 'linear'
        % Linear baseline pinned between end regions
        if isfield(opts, 'n_pts')
            n_pts = opts.n_pts;
        else
            n_pts = 5;
        end
        y_left  = mean(y(1:n_pts));
        y_right = mean(y(end-n_pts+1:end));
        x_left  = mean(x(1:n_pts));
        x_right = mean(x(end-n_pts+1:end));
        
        slope = (y_right - y_left) / (x_right - x_left);
        intercept = y_left - slope * x_left;
        
        y_bkg = slope * x + intercept;
        bkg_params = struct('type', 'linear', 'slope', slope, 'intercept', intercept);
        
    case 'shirley'
        % Iterative Shirley Background 
        if isfield(opts, 'max_iter')
            max_iter = opts.max_iter;
        else
            max_iter = 50; % Default value if not specified
        end

        if isfield(opts, 'tol')
            tol = opts.tol;
        else
            tol = 1e-5;
        end
        
        if isfield(opts, 'n_pts')
            n_pts = opts.n_pts;
        else
            n_pts = 5;
        end

        y_left  = mean(y(1:n_pts));     % High BE background
        y_right = mean(y(end-n_pts+1:end)); % Low BE background
        
        % Initialize Shirley as linear
        y_bkg = y_right + (y_left - y_right) * (x - x(end)) / (x(1) - x(end));
        
        dx = abs(mean(diff(x)));
        for iter = 1:max_iter
            y_sub = y - y_bkg;
            y_sub(y_sub < 0) = 0; % Non-negative integral
            
            % Cumulative integral from low BE to high BE
            cum_int = cumsum(y_sub) * dx;
            tot_int = cum_int(end);
            
            if tot_int == 0, break; end
            
            y_bkg_new = y_right + (y_left - y_right) * (cum_int / tot_int);
            
            if max(abs(y_bkg_new - y_bkg)) < tol
                y_bkg = y_bkg_new;
                break;
            end
            y_bkg = y_bkg_new;
        end
        bkg_params = struct('type', 'shirley', 'iterations', iter);
        
    case 'asls'
        % Asymmetric Least Squares (AsLS) Baseline

        if isfield(opts, 'lambda')
            lambda = opts.lambda;
        else
            lambda = 1e5; % Default smoothness parameter
        end

        if isfield(opts, 'p')
            p = opts.p;
        else
            p = 0.01;
        end

        if isfield(opts, 'max_iter')
            max_iter = opts.max_iter;
        else
            max_iter = 20;
        end
        
        D = diff(speye(N), 2);
        w = ones(N, 1);
        
        for iter = 1:max_iter
            W = spdiags(w, 0, N, N);
            C = cholesky_solve(W + lambda * (D' * D), w .* y);
            w_new = p * (y > C) + (1 - p) * (y <= C);
            if max(abs(w_new - w)) < 1e-4
                C = cholesky_solve(W + lambda * (D' * D), w .* y);
                break;
            end
            w = w_new;
        end
        y_bkg = C;
        bkg_params = struct('type', 'asls', 'lambda', lambda, 'p', p, 'iter', iter);
        
    case 'tougaard'
        % Universal Tougaard Background (B = 2866 eV^2)

        if isfield(opts, 'B')
            B = opts.B;
        else
            B = 2866;
        end

        if isfield(opts, 'C')
            C = opts.C;
        else
            C = 1643;
        end
        
        dx = abs(mean(diff(x)));
        y_bkg = zeros(N, 1);
        
        % Convolution integral for inelastic loss
        for i = 1:N
            E_i = x(i);
            loss_kernel = zeros(i, 1);
            for j = 1:i
                T = x(j) - E_i; % Energy loss
                if T > 0
                    loss_kernel(j) = (B * T) / ((C + T^2)^2);
                end
            end
            y_bkg(i) = dx * sum(y(1:i) .* loss_kernel);
        end
        % Scale baseline to match right boundary
        y_bkg = y_bkg + mean(y(end-5:end));
        bkg_params = struct('type', 'tougaard', 'B', B, 'C', C);
        
    otherwise
        error('Unknown background type: %s', type);
end
end

function x = cholesky_solve(A, b)
    % Fast sparse linear solver
    R = chol(A);
    x = R \ (R' \ b);
end