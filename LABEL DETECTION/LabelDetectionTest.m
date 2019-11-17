img = imread('input2.jpg');
img_double = im2double(img);
img_grey = rgb2gray(img_double);

%test_img_threshold = (img_grey > 0.85) & (img_grey < 0.95);

%{
imshow(img_threshold);
figure(2);
se = strel('rectangle', [5,5]);
imshow(imdilate(img_threshold, se));
%}

%% CORNER DETECTION
img_grey_gaus = imgaussfilt(img_grey, 4);
corners = corner(img_grey_gaus, 5000, 'FilterCoefficients', fspecial('gaussian',[9 1], 2));
corners = [corners(:, 2), corners(:, 1)]; % swap columns so it's roght
%corners = detect_corners(img_grey_gaus);
img_corner_highlight = img_grey;


%% INTEGRAL IMAGING
img_integral = generate_integral_image(img_grey);

%% FIND LABELS
brights_darks_ratio_range = [10, 50];   % ratio between II brightness sum/II darkness sum [min acceptable, max acceptable]
x_diff_range = [50, 125];               % absolute distance that two corners need to be apart in x direction [min, max]
y_diff_range = [100, 200];              % absolute distance that two corners need to be apart in y direction [min, max]
labels = [];
corners = sortrows(corners);

for c = 1:size(corners, 1)          % for every corner, find neighbors within x_diff_range and y_diff_range and check bright/dark ratio
    % quadtree to find neaarest neighbor with minimum distance of
    % [x_diff_range(1), y_diff_range(1)] and maximum distance of [x_diff_range(2), y_diff_range(2)]
    % if no other corner is in range, ignore the current corner and move on
    % if another corner is found in range, do integral imaging and
    % calculate the brightness/darkness ratio

    neighbors = find_neighbors(corners, c, x_diff_range, y_diff_range);
    for n = 1:size(neighbors, 1)
        if check_if_label(img_integral, corners(c, :), neighbors(n, :), brights_darks_ratio_range)
            labels = [labels; corners(c, :), neighbors(n, :)];
        end
    end
    
end

corners_t = corner(img_grey_gaus, 5000, 'FilterCoefficients', fspecial('gaussian',[9 1], 2));
imshow(img_grey);
hold on;
plot([labels(:, 1), labels(:, 3)], [labels(:, 2), labels(:, 4)]);
for c = 1:size(corners_t, 1)
    th = 0:pi/50:2*pi;
    r = 5;
    x = r * cos(th) + corners_t(c, 1);
    y = r * sin(th) + corners_t(c, 2);
    plot(x, y, 'r');
end
hold off;

% labels contains final result

%% FUNCTIONS
function result = find_neighbors(coords, coords_target_index, x_diff_range, y_diff_range)
    % find nearest neighbors in range
    
    result = [];
    for j = coords_target_index + 1:size(coords, 1)
        neighbor = coords(j, :);
        if check_for_range(coords(coords_target_index, :), neighbor, x_diff_range, y_diff_range)
            %disp(corners_x(i,:));
            %disp(next);
            %plot([corners_x(i,1), next(1,1)], [corners_x(i,2), next(1,2)]); 
            result = [result; neighbor];
        end
    end
    
end

%check if the two points are not too far from each other
function result = check_for_range(coordA, coordB, x_diff_range, y_diff_range)

    diff_x = abs(coordA(1) - coordB(1));
    diff_y = abs(coordA(2) - coordB(2));
    
    result = diff_x >= x_diff_range(1) && ...
             diff_x <= x_diff_range(2) && ...
             diff_y >= y_diff_range(1) && ...
             diff_y <= y_diff_range(2);
   
end

%{
    Returns true if the two target vectors could describe a label (based on
    a heuristic), or false if it is no label that can be detected.

    Sources:
        http://delivery.acm.org/10.1145/810000/808600/p207-crow.pdf
        accessed on 2019/11/12

        https://en.wikipedia.org/wiki/Summed-area_table#/media/File:Summed_area_table.png
        used only for variable naming
        accessed on 2019/11/12

    Author:
        Laurenz Edmund Fiala (11807869)
%}
function result = check_if_label(integral_image, target_coords, target_coords_2, brights_darks_ratio_range)
    
    A = integral_image(target_coords(1), target_coords(2));
    B = integral_image(target_coords(1), target_coords_2(2));
    C = integral_image(target_coords_2(1), target_coords(2));
    D = integral_image(target_coords_2(1), target_coords_2(2));
    
    target_diff   = abs(diff([target_coords(1), target_coords_2(1), target_coords(2), target_coords_2(2)]));
    ii_max_value  = target_diff(1) * target_diff(2);
    ii_brightness = D + A - B - C;
    ii_darkness   = ii_max_value - ii_brightness;
    
    ii_bright_dark_ratio = ii_brightness / max(ii_darkness, 0.000000000001);
    
    result = ii_bright_dark_ratio >= brights_darks_ratio_range(1) && ...
             ii_bright_dark_ratio <= brights_darks_ratio_range(2);

end

%{
    Returns an integral image (also called summed area table) from the
    given grayscale image (2-dimensional, [0, 1]-image).

    Sources:
        http://delivery.acm.org/10.1145/810000/808600/p207-crow.pdf
        accessed on 2019/11/12

    Author:
        Laurenz Edmund Fiala (11807869)
%}
function result = generate_integral_image(greyscale_image)
    
    result = greyscale_image;
    for x = 1:size(greyscale_image, 1)
       for y = 1:size(greyscale_image, 2)
           
           r = 0;
           if x > 1
               r = r + result(x-1, y);
           end
           
           if y > 1 
               r = r + result(x, y-1);
           end
           
           if x > 1 && y > 1
               r = r - result(x-1, y-1);
           end
           
           result(x, y) = r + greyscale_image(x, y);
           
       end
    end

end

%{
    Detect corners in the given binary image (already edge-filtered) and
    return the detected points as line vectors.
%}%{
function result = detect_corners(binary_edge_image)
    
    im = edge(rgb2gray(im2double(imread('input2.jpg'))), 'sobel');

    dx = fspecial('gaussian', [1 9], 5);
    dy = fspecial('gaussian', [9 1], 5);
    
    % Step 1: Compute derivatives of image
    Ix = conv2(im, dx, 'same');
    Iy = conv2(im, dy, 'same');
    
    imshow(Ix);
    figure(2);
    imshow(Iy);
    
    % Step 2: Smooth space image derivatives (gaussian filtering)
    Ix2 = imgaussfilt(Ix .^ 2, [1 9]);
    Iy2 = imgaussfilt(Iy .^ 2, [9 1]);
    Ixy = imgaussfilt(Ix .* Iy, 9);
    
    imshow(Ixy);

    % Step 3: Harris corner measure
    harris = (Ix2 .* Iy2 - Ixy .^ 2) ./ (Ix2 + Iy2);

    % Step 4: Find local maxima (non maximum suppression)
    mx = ordfilt2(harris, size(im, 1) .^ 2, ones(size(im, 1)));
    
    plot(mx);

    % Step 5: Thresholding
    %harris = (harris == mx) & (harris > threshold);
    
    %{
im1 = rgb2gray(im2double(imread('input2.jpg')));
%figure ;imshow(im1);
dx = [-1 0 1; -1 0 1; -1 0 1]; % image derivatives
dy = dx';
Ix = imfilter(im1, dx);    % Step 1: Compute the image derivatives Ix and Iy
Iy = imfilter(im1, dy);
g = fspecial('gaussian',9,2); % Step 2: Generate Gaussian filter 'g' of size 9x9 and standard deviation Sigma=2.
Ix2 = imfilter(Ix.^2, g); % Step 3: Smooth the squared image derivatives to obtain Ix2, Iy2 and IxIy
%figure;imshow(Ix2);
Iy2 = imfilter(Iy.^2, g);
%figure;imshow(Iy2);
IxIy = imfilter(Ix.*Iy, g);
%figure;imshow(IxIy);
[r c]=size(Ix2);
E = zeros(r, c); % Compute matrix E
tic
for i=2:1:r-1 
    for j=2:1:c-1
     Ix21=sum(sum(Ix2(i-1:i+1,j-1:j+1)));
     Iy21=sum(sum(Iy2(i-1:i+1,j-1:j+1)));
     IxIy1= sum(sum(IxIy(i-1:i+1,j-1:j+1)));
     M=[Ix21 IxIy1;IxIy1 Iy21]; %(1) Build autocorrelation matrix for every singe pixel considering a window of size 3x3
     E(i,j)=min(eig(M)); %(2)Compute Eigen value of the autocorrelation matrix and save the minimum eigenvalue as the desired value.
    end
end
t=toc;
disp('time needed for calculating E matrix');
disp(t);
figure, imshow(mat2gray(E)); % display result
%}
end
%}
