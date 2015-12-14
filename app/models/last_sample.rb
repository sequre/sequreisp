class LastSample < ActiveRecord::Base
  belongs_to :model, :polymorphic => true
end
