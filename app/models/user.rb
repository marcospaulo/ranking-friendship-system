class User < ActiveRecord::Base
  attr_accessible :name
  
  # Social part
  
    # follow a user
    def follow!(user)
      $redis.multi do
        $redis.sadd(self.redis_key(:following), user.id)
        $redis.sadd(user.redis_key(:followers), self.id)
      end
    end

    # unfollow a user
    def unfollow!(user)
      $redis.multi do
        $redis.srem(self.redis_key(:following), user.id)
        $redis.srem(user.redis_key(:followers), self.id)
      end
    end

    # users that self follows
    def followers
      user_ids = $redis.smembers(self.redis_key(:followers))
      User.where(:id => user_ids)
    end

    # users that follow self
    def following
      user_ids = $redis.smembers(self.redis_key(:following))
      User.where(:id => user_ids)
    end

    # users who follow and are being followed by self
    def friends
      user_ids = $redis.sinter(self.redis_key(:following), self.redis_key(:followers))
      User.where(:id => user_ids)
    end
    
    # does the user follow self
    def followed_by?(user)
      $redis.sismember(self.redis_key(:followers), user.id)
    end

    # does self follow user
    def following?(user)
      $redis.sismember(self.redis_key(:following), user.id)
    end

    # number of followers
    def followers_count
      $redis.scard(self.redis_key(:followers))
    end

    # number of users being followed
    def following_count
      $redis.scard(self.redis_key(:following))
    end

    # key generator for user's redis keys
    def redis_key(str)
      "user:#{self.id}:#{str}"
    end
    
  # About ranking part
    
    # how many points did the self made
    def scored(score)
      if score > self.high_score
        $redis.zadd("highscores", score, self.id)
      end
    end

    # table rank
    def rank
      $redis.zrevrank("highscores", self.id) + 1
    end

    # high score
    def high_score
      $redis.zscore("highscores", self.id).to_i
    end

    # load top 3 users
    def self.top_3
      $redis.zrevrange("highscores", 0, 2).map{|id| User.find(id)}
    end
    
  # About Who's connected part
    
    # make the self online
    def connect
      key = current_time_key
      $redis.sadd(key, self.id)
    end
    
    # get the key that will store the users that went online at that time
    def current_time_key
      time_key(Time.now.strftime("%M"))
    end
    
    # get the keys that were used in the last 5 minutes to store the users that went online
    def keys_in_last_5_minutes
      now = Time.now
      times = (0..5).collect {|n| now - n.minutes}
      times.collect{|t| time_key(t.strftime("%M"))}
    end
    
    # key generator to store the online users
    def time_key(minute)
      "online_users_per_minute:#{minute}"
    end
    
    # who's online?
    def self.online_users
      $redis.sunion(*keys_in_last_5_minutes)
    end
    
    # get the followers that are online
    def online_followers
      $redis.sunionstore("online_users", *keys_in_last_5_minutes)
      $redis.sinter("online_users", self.redis_key(:followers))
    end

    # get the online users that follow self
    def online_following
      $redis.sunionstore("online_users", *keys_in_last_5_minutes)
      $redis.sinter("online_users", self.redis_key(:following))
    end      
    
end
