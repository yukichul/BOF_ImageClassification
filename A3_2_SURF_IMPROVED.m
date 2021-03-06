% Yuan Gao, Rice University

%% Collecting phase
close all
clear
root = '/Users/gaoyuan/Documents/MATLAB/';
numOfCluster = 300;
confusionMatrix = zeros(25,25);
CLASS_IDX = cell(25,1);
bin = (1:numOfCluster * 25);
TRAINING_DATA = dir(strcat(root,'TrainingDataset/'));
TRAINING_SET = struct();
[numOfClass, ~] = size(TRAINING_DATA);
centroids = [];
% load all images from testing data 
% this creates a nested struct of struct
mark = 0;
for f = 1: 1: numOfClass
    if (TRAINING_DATA(f).name(1) == '.')
        continue;
    end
    mark = mark + 1;
    TRAINING_SET(mark).CLASS = dir(strcat(root,...
        'TrainingDataset/', TRAINING_DATA(f).name));
    CLASS_IDX{mark} = strtok(TRAINING_DATA(f).name, '.');
end

jmp = numOfClass - mark;
for c = 1: 1: mark
    [numOfImage, ~] = size(TRAINING_SET(c).CLASS);
    d_class_pool = [];
    TRAINING_SET(c).DESCRIPTORS = struct();
    ind = 0;
    for i = 1: 1: numOfImage
        if (TRAINING_SET(c).CLASS(i).name(1) == '.')
            continue;
        end
        ind = ind + 1;
        image = im2double(imread(...
            strcat(root,'TrainingDataset/',TRAINING_DATA(c + jmp).name,...
                '/', TRAINING_SET(c).CLASS(i).name)));
        if (ndims(image) == 3)   
            image = rgb2gray(image);
        end
        pts = detectSURFFeatures(image,'NumOctaves',4);
        [d,~] = extractFeatures(image,pts,'Method','SURF');
        TRAINING_SET(c).DESCRIPTORS(ind).D = d';
        d_class_pool = [d_class_pool d'];
    end
    [centroid_class,~] = vl_kmeans(d_class_pool,numOfCluster);
    centroids = [centroids centroid_class];
    % gathering all features from all pictures
end

%% Training Phase
container_bin = [];
for p = 1: 1: mark
    [numOfImage, ~] = size(TRAINING_SET(p).CLASS);
    class_bin = [];
    count = 0;
    for i = 1: 1 :numOfImage
        if (TRAINING_SET(p).CLASS(i).name(1) == '.')
            continue;
        end
        count = count + 1;
        d_training = TRAINING_SET(p).DESCRIPTORS(count).D;
        [idx, dis] = knnsearch(centroids',double(d_training'));
        thresh_training = prctile(dis, 95);
        idx(dis > thresh_training) = 0;
        training_cnt = histc(idx',bin);
        norm_train_cnt = training_cnt/sum(training_cnt);
        class_bin = [class_bin; norm_train_cnt];
    end
%    TRAINING_SET(p).CLASS_BIN = class_bin;
    container_bin = [container_bin; class_bin];
end

%% Testing phase
TEST_SET = dir(strcat(root,'TestDataset/'));
[numOfImage, ~] = size(TEST_SET);
for j = 1: 1: numOfImage
    filename = TEST_SET(j).name;
    % avoid temp/directory files
    if (filename(1) == '.')
        continue;
    end
    test_image = im2double(imread(strcat(root,...
        'TestDataset/', filename)));
    if (ndims(test_image) == 3)
        test_image = rgb2gray(test_image);
    end
    pts = detectSURFFeatures(test_image,'NumOctaves',4);
    [d_test,~] = extractFeatures(test_image, pts,'Method','SURF');

    % generate the bin hist for each test image
    [test_match_idx, test_dist] = knnsearch(centroids',double(d_test));
    thresh_test = prctile(test_dist, 95);
    test_match_idx(test_dist > thresh_test) = 0;
    test_cnt = histc(test_match_idx',bin);
    n_test_cnt = test_cnt/sum(test_cnt);
    % generate confusion matrix by matching actual and predictions
    prediction_idx = knnsearch(container_bin, n_test_cnt,...
        'Distance','Euclidean');
    if (prediction_idx < 1200)
        prediction = floor(prediction_idx / 50) + 1;
    else
        prediction = 25;
    end
    actual = find(strcmp(strtok(TEST_SET(j).name, '_'), CLASS_IDX));
    confusionMatrix(actual,prediction) =...
        confusionMatrix(actual,prediction) + 1;
end

for k = 1:1:25
    confusionMatrix(k,:) = confusionMatrix(k,:)/sum(confusionMatrix(k,:));
end
avgRate = sum(diag(confusionMatrix))/25
